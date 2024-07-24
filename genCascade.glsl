layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
uniform vec2 res;

uniform uint numCascade;
uniform uint cascadeIndex;
uniform uint probeDim0;
uniform float rayStart;
uniform float rayEnd;
uniform uint depthOffset;
uniform uint depthOffset2;

void main(){
	
	const uvec2 tid = gl_GlobalInvocationID.xy;
	const uint probeDim = probeDim0 << cascadeIndex;
	
	float fProbeDim = float(probeDim);
	

	uvec2 probeID = tid / probeDim;
	uvec2 rayID = tid % probeDim;
	vec2 octUV = (vec2(rayID) + 0.5) / fProbeDim; // 0 to 1
	
	vec2 probePixCoor = (vec2(probeID) + 0.5) * (1 << cascadeIndex);
	uint depthArrayIndex = cascadeIndex == 0 ? 0 : 2;

	PixelData p;
	if(cascadeIndex == 0 || false){
		p.minCoor = probeID;
		p.maxCoor = p.minCoor;
		p.minDist = abs(imageLoad(depth, ivec3(probeID, 0)).r);
		p.maxDist = p.minDist;
	}
	else{
		uvec4 data = imageLoad(depthMip, ivec2(probeID + uvec2(depthOffset, 0)));
		p.minDist = uintBitsToFloat(data.r);
		p.minCoor = uvec2(data.g & 0xFFFF, (data.g >> 16) & 0xFFFF);
		p.maxDist = uintBitsToFloat(data.b);
		p.maxCoor = uvec2(data.w & 0xFFFF, (data.w >> 16) & 0xFFFF);
	}

	Ray r;
	r.dir = octDecode(octUV);
	r.pos = currentScreenToWorld(p.minCoor, p.minDist) + r.dir * rayStart;
	r.len = rayEnd - rayStart;
	r.vox = 0;

	Hit h;
	float col;
	bool found = false;
	bool needTrace = length(r.pos - camPos) < 4000;
	if(needTrace){
		found = raytrace(r, h, col);
	}
	vec3 LiMin = vec3(0);
	float vMin = float(!found);

	Material m = getMaterial(h.vox);
	if(found) LiMin = m.emmissivity + getNEE(h, false) * m.baseColor;
	else if(cascadeIndex == numCascade - 1) LiMin += sampleSky(r.dir);
	

	r.pos = currentScreenToWorld(p.maxCoor, p.maxDist) + r.dir * rayStart;
	if(needTrace){
		found = raytrace(r, h, col);
	}
	vec3 LiMax = vec3(0);
	float vMax = float(!found);
	
	m = getMaterial(h.vox);
	if(found) LiMax = m.emmissivity + getNEE(h, false) * m.baseColor;
	else if(cascadeIndex == numCascade - 1) LiMax += sampleSky(r.dir);

  	const bool USE_MIN	= bool(0);
  	const bool USE_MAX	= bool(0);
  	const bool USE_BOTH 	= bool(1);

  	vec2 clampFactor = USE_MAX ? vec2(1) : USE_MIN ? vec2(0) : vec2(0, 1);

 	if(cascadeIndex < numCascade - 1){
	  	int iProbeDim = int(probeDim);
	  	float probePixDim = float(1 << (cascadeIndex + 1));
	  	//fProbeDim or fPixDim???
	  	ivec2 blProbeID = clamp(ivec2((probePixCoor - 0.5 * probePixDim) / probePixDim), ivec2(0), ivec2(res/probePixDim) - 2);
	 	ivec2 f = octMirror(ivec2(probeDim * octEncode(r.dir)), iProbeDim);
	 	ivec2 blTexCoor = blProbeID.xy * iProbeDim;
		vec2 blProbePixCoor = blTexCoor + 0.5 * probePixCoor;
		vec2 fr = (probePixCoor - blProbePixCoor) / probePixDim;

	  	uvec4 blColor = imageLoad(downSampledCascade, ivec3(blTexCoor + f,					   cascadeIndex));
	  	uvec4 brColor = imageLoad(downSampledCascade, ivec3(blTexCoor + f + ivec2(iProbeDim, 0), cascadeIndex));
	  	uvec4 tlColor = imageLoad(downSampledCascade, ivec3(blTexCoor + f + ivec2(0, iProbeDim), cascadeIndex));
	  	uvec4 trColor = imageLoad(downSampledCascade, ivec3(blTexCoor + f + ivec2(iProbeDim   ), cascadeIndex));

    		vec4 blMin = vec4(unpackHalf2x16(blColor.r), unpackHalf2x16(blColor.g));
    		vec4 blMax = vec4(unpackHalf2x16(blColor.b), unpackHalf2x16(blColor.w));
    		vec4 brMin = vec4(unpackHalf2x16(brColor.r), unpackHalf2x16(brColor.g));
    		vec4 brMax = vec4(unpackHalf2x16(brColor.b), unpackHalf2x16(brColor.w));
    		vec4 tlMin = vec4(unpackHalf2x16(tlColor.r), unpackHalf2x16(tlColor.g));
    		vec4 tlMax = vec4(unpackHalf2x16(tlColor.b), unpackHalf2x16(tlColor.w));
    		vec4 trMin = vec4(unpackHalf2x16(trColor.r), unpackHalf2x16(trColor.g));
    		vec4 trMax = vec4(unpackHalf2x16(trColor.b), unpackHalf2x16(trColor.w));

    		vec4 iDistRange = vec4(1.) / vec4(blMax.w - blMin.w, brMax.w - brMin.w, tlMax.w - tlMin.w, trMax.w - trMin.w);
    		vec4 deltaDist = vec4(blMax.w - p.minDist, brMax.w - p.minDist, tlMax.w - p.minDist, trMax.w - p.minDist);

    		vec4 minmaxW = vec4(	clamp(1 - (blMax.w - p.minDist) * iDistRange.x, clampFactor.x, clampFactor.y),
					clamp(1 - (brMax.w - p.minDist) * iDistRange.y, clampFactor.x, clampFactor.y),
					clamp(1 - (tlMax.w - p.minDist) * iDistRange.z, clampFactor.x, clampFactor.y),
					clamp(1 - (trMax.w - p.minDist) * iDistRange.w, clampFactor.x, clampFactor.y));


    		vec4 bl = mix(blMin, blMax, minmaxW.r);
    		vec4 br = mix(brMin, brMax, minmaxW.g);
    		vec4 tl = mix(tlMin, tlMax, minmaxW.b);
    		vec4 tr = mix(trMin, trMax, minmaxW.a);

    		vec4 ds = vec4(bl.w, br.w, tl.w, tr.w);
    		vec4 dw = exp(-(abs(p.minDist - ds)/p.minDist)*6);
    		vec4 w = vec4((1 - fr.x) * (1 - fr.y) , fr.x * (1 - fr.y), (1 - fr.x) * fr.y, fr.x * fr.y) * dw;

    		float sw = w.x + w.y + w.z + w.w;
    		w /= sw;
    		vec3 Ri = bl.rgb * w.x + br.rgb * w.y + tl.rgb * w.z + tr.rgb * w.w;

    		LiMin += Ri * vMin;
    		minmaxW = vec4(	clamp(1 - (blMax.w - p.maxDist) * iDistRange.x, clampFactor.x, clampFactor.y),
				clamp(1 - (brMax.w - p.maxDist) * iDistRange.y, clampFactor.x, clampFactor.y),
				clamp(1 - (tlMax.w - p.maxDist) * iDistRange.z, clampFactor.x, clampFactor.y),
				clamp(1 - (trMax.w - p.maxDist) * iDistRange.w, clampFactor.x, clampFactor.y));

		bl = mix(blMin, blMax, minmaxW.r);
		br = mix(brMin, brMax, minmaxW.g);
		tl = mix(tlMin, tlMax, minmaxW.b);
		tr = mix(trMin, trMax, minmaxW.a);

    		ds = vec4(bl.w, br.w, tl.w, tr.w);
		dw = exp(-(abs(p.maxDist - ds)/p.maxDist)*6);
		w = vec4((1 - fr.x) * (1 - fr.y) , fr.x * (1 - fr.y), (1 - fr.x) * fr.y, fr.x * fr.y) * dw;
		sw = w.x + w.y + w.z + w.w;
		w /= sw;
		Ri = bl.rgb * w.x + br.rgb * w.y + tl.rgb * w.z + tr.rgb * w.w;

		LiMax += Ri * vMax;
	}
  uvec4 LoData = uvec4(packHalf2x16(LiMin.rg), packHalf2x16(vec2(LiMin.b, p.minDist)), packHalf2x16(LiMax.rg), packHalf2x16(vec2(LiMax.b, p.maxDist)));
  imageStore(Lo, ivec3(tid, cascadeIndex), LoData);
