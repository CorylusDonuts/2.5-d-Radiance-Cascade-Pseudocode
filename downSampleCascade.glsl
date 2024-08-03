//No longer needed

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

uniform vec2 res;
uniform uint probeDim0;
uniform uint numCascade;

uniform uint cascadeIndex;
uniform uint depthOffset;

struct MinMaxInterval{
	vec3 minLo;
	float minDist;
	vec3 maxLo;
	float maxDist;
};

MinMaxInterval getMinMaxRadianceInterval(vec2 coor, vec3 dir, unsigned int cascadeIndex){
	MinMaxInterval I;
	int probeDim = int(probeDim0 << cascadeIndex);
	ivec2 probeID = ivec2(coor / (1 << cascadeIndex));
	vec2 f = octEncode(dir) * probeDim - vec2(0.5);
	ivec2 texCoor0 = probeID.xy * probeDim;
	ivec2 texCoorBL = ivec2(f);
	ivec2 texCoorBR = octMirror(texCoorBL + ivec2(1, 0), probeDim);
	ivec2 texCoorTL = octMirror(texCoorBL + ivec2(0, 1), probeDim);
	ivec2 texCoorTR = octMirror(texCoorBL + ivec2(1, 1), probeDim);
	texCoorBL = octMirror(texCoorBL, probeDim);
	f = fract(abs(f));

	uvec4 data = imageLoad(Lo, ivec3(texCoor0 + texCoorBL, cascadeIndex));

	vec4 blMin = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	vec4 blMax = vec4(unpackHalf2x16(data.b), unpackHalf2x16(data.w));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorBR, cascadeIndex));
	vec4 brMin = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	vec4 brMax = vec4(unpackHalf2x16(data.b), unpackHalf2x16(data.w));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorTL, cascadeIndex));
	vec4 tlMin = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	vec4 tlMax = vec4(unpackHalf2x16(data.b), unpackHalf2x16(data.w));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorTR, cascadeIndex));
	vec4 trMin = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	vec4 trMax = vec4(unpackHalf2x16(data.b), unpackHalf2x16(data.w));


	vec3 t = mix(tlMin.rgb, trMin.rgb, f.x);
	vec3 b = mix(blMin.rgb, brMin.rgb, f.x);

	I.minLo = mix(b, t, f.y);
	I.minDist = blMin.w;
	
	t = mix(tlMax.rgb, trMax.rgb, f.x);
	b = mix(blMax.rgb, brMax.rgb, f.x);

	I.maxLo = mix(b, t, f.y);
	I.maxDist = blMax.w;

	return I;
}

void main(){
	const uvec2 tid = gl_GlobalInvocationID.xy;
	const uint probeDim = probeDim0 << cascadeIndex;
	
	float fProbeDim = float(probeDim);
	

	uvec2 probeID = tid / probeDim;
	uvec2 rayID = tid % probeDim;
	vec2 octUV = (vec2(rayID) + 0.5) / fProbeDim; // 0 to 1
	
	vec2 probePixCoor = (vec2(probeID) * 2 + 1) * (1 << cascadeIndex);

	vec3 dir = octDecode(octUV);

	MinMaxInterval I = getMinMaxRadianceInterval(probePixCoor, dir, cascadeIndex + 1);
	uvec4 data = uvec4(packHalf2x16(I.minLo.rg), packHalf2x16(vec2(I.minLo.b, I.minDist)), packHalf2x16(I.maxLo.rg), packHalf2x16(vec2(I.maxLo.b, I.maxDist)));

	imageStore(downSampledCascade, ivec3(gl_GlobalInvocationID.xy, cascadeIndex), data);
}
