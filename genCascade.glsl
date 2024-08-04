#extension GL_KHR_shader_subgroup_basic: enable
#extension GL_KHR_shader_subgroup_clustered : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
uniform vec2 res;

uniform uint numCascade;
uniform uint cascadeIndex;
uniform uint probeDim0;
uniform float rayStart;
uniform float rayEnd;
uniform uint depthOffset;
uniform uint depthOffset2;

//minDist minCoor maxDist maxCoor
struct PixelData{
	uvec2 minMaxCoor[2];
	float minMaxDist[2];
};


struct MinMaxInterval{
	vec3 minMaxLi[2];
	float minMaxDepth[2];
};

const int probeDim = int(probeDim0 << cascadeIndex);
float fProbeDim = float(probeDim);
uint depthArrayIndex = cascadeIndex == 0 ? 0 : 2;
const bool isHighestCascade = cascadeIndex == numCascade - 1;

const uint ltidx = gl_SubgroupSize * gl_SubgroupID + gl_SubgroupInvocationID; //local thread index
const uvec2 tid = uvec2((((ltidx >> 2) & 3) << 1) + (ltidx & 1), ((ltidx >> 4) << 1) + ((ltidx >> 1) & 1)) + gl_WorkGroupID.xy * gl_WorkGroupSize.xy; //swizzled global thread id

MinMaxInterval genRadianceInterval(){
	MinMaxInterval I;

	uvec2 probeID = tid / probeDim;
	uvec2 rayID = tid % probeDim;
	vec2 octUV = (vec2(rayID) + 0.5) / fProbeDim; // 0 to 1
	vec2 probePixCoor = (vec2(probeID) + 0.5) * (1 << cascadeIndex);

	PixelData p;
	if(cascadeIndex == 0 || false){
		p.minMaxCoor[0] = probeID;
		p.minMaxCoor[1] = p.minMaxCoor[0];
		p.minMaxDist[0] = abs(imageLoad(depth, ivec3(probeID, 0)).r);
		p.minMaxDist[1] = p.minMaxDist[0];
	}
	else {
		uvec4 data = imageLoad(depthMip, ivec2(probeID + uvec2(depthOffset, 0)));
		p.minMaxDist[0] = uintBitsToFloat(data.r);
		p.minMaxCoor[0] = uvec2(data.g & 0xFFFF, (data.g >> 16) & 0xFFFF);
		p.minMaxDist[1] = uintBitsToFloat(data.b);
		p.minMaxCoor[1] = uvec2(data.w & 0xFFFF, (data.w >> 16) & 0xFFFF);
	}
	

	Ray r;
	r.dir = octDecode(octUV);
	r.vox = 0;

	Hit h;

	float visibility[2];

	float col;//useless var
	for(uint i = 0; i < 2; i++){
		r.pos = currentScreenToWorld(p.minMaxCoor[i], p.minMaxDist[i]) + r.dir * rayStart;
		r.len = rayEnd - rayStart;

		bool found = false;
		bool needTrace = length(r.pos - camPos) < 4000;
		if(needTrace){
			found = raytrace(r, h, col);
		}
		I.minMaxLi[i] = vec3(0);
		I.minMaxDepth[i] = p.minMaxDist[i];
		visibility[i] = float(!found);

		Material m = getMaterial(h.vox);
		if(found) I.minMaxLi[i] = m.emmissivity + getNEE(h, false) * m.baseColor;
		else if(isHighestCascade) I.minMaxLi[i] += sampleSky(r.dir);
	}


	if(!isHighestCascade){
		float probePixDim = float(1 << (cascadeIndex + 1));
		//fProbeDim or fPixDim???
		ivec2 texCoor = clamp(ivec2((probePixCoor - 0.5 * probePixDim) / probePixDim), ivec2(0), ivec2(res/probePixDim) - 2) * probeDim;
		vec2 fr = (probePixCoor - (texCoor + 0.5 * probePixCoor)) / probePixDim;
		texCoor += octMirror(ivec2(probeDim * octEncode(r.dir)), probeDim);

		uvec4 blData = imageLoad(Lo, ivec3(texCoor,							cascadeIndex + 1));
		uvec4 brData = imageLoad(Lo, ivec3(texCoor + ivec2(probeDim, 0),	cascadeIndex + 1));
		uvec4 tlData = imageLoad(Lo, ivec3(texCoor + ivec2(0, probeDim),	cascadeIndex + 1));
		uvec4 trData = imageLoad(Lo, ivec3(texCoor + ivec2(probeDim   ),	cascadeIndex + 1));

		vec4 blMin = vec4(unpackHalf2x16(blData.r), unpackHalf2x16(blData.g));
		vec4 blMax = vec4(unpackHalf2x16(blData.b), unpackHalf2x16(blData.w));
		vec4 brMin = vec4(unpackHalf2x16(brData.r), unpackHalf2x16(brData.g));
		vec4 brMax = vec4(unpackHalf2x16(brData.b), unpackHalf2x16(brData.w));
		vec4 tlMin = vec4(unpackHalf2x16(tlData.r), unpackHalf2x16(tlData.g));
		vec4 tlMax = vec4(unpackHalf2x16(tlData.b), unpackHalf2x16(tlData.w));
		vec4 trMin = vec4(unpackHalf2x16(trData.r), unpackHalf2x16(trData.g));
		vec4 trMax = vec4(unpackHalf2x16(trData.b), unpackHalf2x16(trData.w));

		vec4 iDistRange = vec4(1.) / vec4(blMax.w - blMin.w, brMax.w - brMin.w, tlMax.w - tlMin.w, trMax.w - trMin.w);
		vec4 bw = vec4((1 - fr.x) * (1 - fr.y) , fr.x * (1 - fr.y), (1 - fr.x) * fr.y, fr.x * fr.y); //bilinear weight
		
		for(uint i = 0; i < 2; i++){
			vec4 deltaDist = vec4(blMax.w - p.minMaxDist[i], brMax.w - p.minMaxDist[i], tlMax.w - p.minMaxDist[i], trMax.w - p.minMaxDist[i]);
			vec4 minmaxW = vec4(clamp(1 - (blMax.w - p.minMaxDist[i]) * iDistRange.x, 0, 1),
								clamp(1 - (brMax.w - p.minMaxDist[i]) * iDistRange.y, 0, 1),
								clamp(1 - (tlMax.w - p.minMaxDist[i]) * iDistRange.z, 0, 1),
								clamp(1 - (trMax.w - p.minMaxDist[i]) * iDistRange.w, 0, 1));
			vec4 bl = mix(blMin, blMax, minmaxW.r);
			vec4 br = mix(brMin, brMax, minmaxW.g);
			vec4 tl = mix(tlMin, tlMax, minmaxW.b);
			vec4 tr = mix(trMin, trMax, minmaxW.a);

			vec4 ds = vec4(bl.w, br.w, tl.w, tr.w);
			vec4 dw = exp(-(abs(p.minMaxDist[i] - ds)/p.minMaxDist[i])*32); //bilateral weight
			vec4 w = bw * dw;
			float sw = w.x + w.y + w.z + w.w;
			w /= sw;

			I.minMaxLi[i] += vec3(bl.rgb * w.x + br.rgb * w.y + tl.rgb * w.z + tr.rgb * w.w) * visibility[i];
		}
	}
	return I;
}

uvec4 encodeInterval(in MinMaxInterval I){
	return uvec4(packHalf2x16(I.minMaxLi[0].rg), packHalf2x16(vec2(I.minMaxLi[0].b, I.minMaxDepth[0])), packHalf2x16(I.minMaxLi[1].rg), packHalf2x16(vec2(I.minMaxLi[1].b, I.minMaxDepth[1])));
}

MinMaxInterval decodeInterval(in uvec4 d){
	vec4 minLiDist = vec4(unpackHalf2x16(d.r), unpackHalf2x16(d.g));
	vec4 maxLiDist = vec4(unpackHalf2x16(d.b), unpackHalf2x16(d.a));
	return MinMaxInterval(vec3[2](vec3(minLiDist.rgb), vec3(maxLiDist.rgb)), float[2](minLiDist.a, maxLiDist.a));
}

void main(){

	MinMaxInterval I = genRadianceInterval();
	I.minMaxLi[0] = subgroupClusteredAdd(I.minMaxLi[0], 4) * 0.25;
	I.minMaxLi[1] = subgroupClusteredAdd(I.minMaxLi[1], 4) * 0.25;
	
	if((ltidx & 3) == 0) imageStore(Lo, ivec3(tid >> 1, cascadeIndex), encodeInterval(I));
}
