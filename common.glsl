bool raytrace(in Ray ray, out Hit hit) {
  return false;
}
//next event estimation/direct lighting via shadow map
float getNEE(in Hit h, in bool highQuality){
  return 0.;
}


//THIS IS WRONG, THE INTERPOLATION IS STILL NOT SMOOTH
ivec2 octMirror(in ivec2 texCoor, in int probeDim){
	ivec2 r = texCoor % probeDim;
	if((max(texCoor.x, texCoor.y) >= probeDim) != (min(texCoor.x, texCoor.y) < 0)) r = (probeDim - 1) - r;//mirror if xor is true
	return r;
}

vec3 octDecode(vec2 f){ //expect 0 to 1
	f = 2 * f - 1;
	vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
	float t = -max(-n.z, 0.0);
	n.xy += sign(n.xy) * t;
	return normalize(n);
}

vec2 octEncode(vec3 n){ //outputs 0 to 1
	n /= (abs(n.x) + abs(n.y) + abs(n.z));
	n.xy = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * sign(n.xy);
	n.xy = n.xy * 0.5 + 0.5;
	return n.xy;
}

vec4 getRadianceInterval(vec2 coor, vec3 dir, unsigned int cascadeIndex){
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
	vec4 bl = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorBR, cascadeIndex));
	vec4 br = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorTL, cascadeIndex));
	vec4 tl = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));
	data = imageLoad(Lo, ivec3(texCoor0 + texCoorTR, cascadeIndex));
	vec4 tr = vec4(unpackHalf2x16(data.r), unpackHalf2x16(data.g));


	vec4 t = mix(tl, tr, f.x);
	vec4 b = mix(bl, br, f.x);
	
	return mix(b, t, f.y);
}

vec4 getDownSampledCascade(vec2 coor, vec3 dir, unsigned int cascadeIndex){
	int probeDim = int(probeDim0 << cascadeIndex);
	ivec2 probeID = ivec2(coor / (1 << cascadeIndex))/2;
	vec2 f = octEncode(dir) * probeDim;
	ivec2 texCoor = probeID.xy * probeDim + octMirror(ivec2(f), int(probeDim));
	return imageLoad(downSampledCascade, ivec3(texCoor, cascadeIndex));
}

struct PixelData{
	uvec2 minCoor;
	uvec2 maxCoor;
	float minDist;
	float maxDist;
};
