layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

uniform layout(binding = 3, r32f) image2DArray depth;
uniform layout(binding = 7, rgba32ui) uimage2D depthMip;

uvec2 pixCoor = gl_GlobalInvocationID.xy;
uniform uint inOffset;
uniform uint outOffset;

void main(){
	uint arrayIndex = outOffset == 0 ? 0 : 2;
	uvec2 doublePixC = 2*pixCoor;

	PixelData p0;
	PixelData p1;
	PixelData p2;
	PixelData p3;
	

	if(outOffset != 0){
		uvec4 data0 = imageLoad(depthMip, ivec2(doublePixC + uvec2(0 + inOffset, 0)));
		uvec4 data1 = imageLoad(depthMip, ivec2(doublePixC + uvec2(1 + inOffset, 0)));
		uvec4 data2 = imageLoad(depthMip, ivec2(doublePixC + uvec2(0 + inOffset, 1)));
		uvec4 data3 = imageLoad(depthMip, ivec2(doublePixC + uvec2(1 + inOffset, 1)));

		p0.minDist = uintBitsToFloat(data0.r);
		p0.minCoor = uvec2(data0.g & 0xFFFF, (data0.g >> 16) & 0xFFFF);
		p0.maxDist = uintBitsToFloat(data0.b);
		p0.maxCoor = uvec2(data0.w & 0xFFFF, (data0.w >> 16) & 0xFFFF);

		p1.minDist = uintBitsToFloat(data1.r);
		p1.minCoor = uvec2(data1.g & 0xFFFF, (data1.g >> 16) & 0xFFFF);
		p1.maxDist = uintBitsToFloat(data1.b);
		p1.maxCoor = uvec2(data1.w & 0xFFFF, (data1.w >> 16) & 0xFFFF);

		p2.minDist = uintBitsToFloat(data2.r);
		p2.minCoor = uvec2(data2.g & 0xFFFF, (data2.g >> 16) & 0xFFFF);
		p2.maxDist = uintBitsToFloat(data2.b);
		p2.maxCoor = uvec2(data2.w & 0xFFFF, (data2.w >> 16) & 0xFFFF);

		p3.minDist = uintBitsToFloat(data3.r);
		p3.minCoor = uvec2(data3.g & 0xFFFF, (data3.g >> 16) & 0xFFFF);
		p3.maxDist = uintBitsToFloat(data3.b);
		p3.maxCoor = uvec2(data3.w & 0xFFFF, (data3.w >> 16) & 0xFFFF);
	}
	else {
		p0.minDist = abs(imageLoad(depth, ivec3(doublePixC + uvec2(0, 0), 0)).r);
		p0.maxDist = p0.minDist;
		p0.minCoor = doublePixC + uvec2(0, 0);
		p0.maxCoor = p0.minCoor;

		p1.minDist = abs(imageLoad(depth, ivec3(doublePixC + uvec2(1, 0), 0)).r);
		p1.maxDist = p0.minDist;
		p1.minCoor = doublePixC + uvec2(1, 0);
		p1.maxCoor = p0.minCoor;

		p2.minDist = abs(imageLoad(depth, ivec3(doublePixC + uvec2(0, 1), 0)).r);
		p2.maxDist = p0.minDist;
		p2.minCoor = doublePixC + uvec2(0, 1);
		p2.maxCoor = p0.minCoor;

		p3.minDist = abs(imageLoad(depth, ivec3(doublePixC + uvec2(1, 1), 0)).r);
		p3.maxDist = p0.minDist;
		p3.minCoor = doublePixC + uvec2(1, 1);
		p3.maxCoor = p0.minCoor;
	}

	if(p1.minDist < p0.minDist) { p0.minDist = p1.minDist; p0.minCoor = p1.minCoor; };
	if(p2.minDist < p0.minDist) { p0.minDist = p2.minDist; p0.minCoor = p2.minCoor; };
	if(p3.minDist < p0.minDist) { p0.minDist = p3.minDist; p0.minCoor = p3.minCoor; };

	//p3.maxDist = 1e2;

	if((p1.maxDist > p0.maxDist && p1.maxDist < 1e5) || p0.maxDist > 1e5) { p0.maxDist = p1.maxDist; p0.maxCoor = p1.maxCoor; };
	if((p2.maxDist > p0.maxDist && p2.maxDist < 1e5) || p0.maxDist > 1e5) { p0.maxDist = p2.maxDist; p0.maxCoor = p2.maxCoor; };
	if((p3.maxDist > p0.maxDist && p3.maxDist < 1e5) || p0.maxDist > 1e5) { p0.maxDist = p3.maxDist; p0.maxCoor = p3.maxCoor; };
	

	uvec4 data = uvec4(floatBitsToUint(p0.minDist), p0.minCoor.x + (p0.minCoor.y << 16), floatBitsToUint(p0.maxDist), p0.maxCoor.x + (p0.maxCoor.y << 16));
	imageStore(depthMip, ivec2(pixCoor + uvec2(outOffset, 0)), data);
}
