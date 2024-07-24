RadianceCascade::RadianceCascade(unsigned int resx, unsigned int resy, unsigned int shadowMapRes)  :
  res(resx, resy),
  dim(dim)
{
	float fRes = float(shadowMapRes);
	glm::vec2 vRes = glm::vec2(res);
	genCascade.setVal<unsigned int>("dim", dim);
	genCascade.setVal<float>("shadowRes", fRes);
	genCascade.setVal<float>("res", vRes.x, vRes.y);
	genCascade.setVal<unsigned int>("probeDim0", CASCADE_0_DIM);
	genCascade.setVal<unsigned int>("numCascade", NUM_CASCADE);


	downSampleCascade.setVal<float>("res", vRes.x, vRes.y);
	downSampleCascade.setVal<unsigned int>("probeDim0", CASCADE_0_DIM);
	downSampleCascade.setVal<unsigned int>("numCascade", NUM_CASCADE);

	float rayStart = 0.01;
	float rayLength = CASCADE_0_RAY_LENGTH;
	float rayEnd = rayStart + rayLength;

	depthRes[0] = res / glm::uvec2(2);
	inoutDepthOffset[0] = glm::uvec2(0);
	for (unsigned int i = 0; i <= NUM_CASCADE; i++) {
		rayLength *= CASCADE_RAY_MULTIPLIER;
		rayStart = rayEnd;
		rayEnd = rayStart + rayLength;
		rayIntervals[i] = glm::vec2(rayStart, rayEnd);

		if (i > 0) {
			depthRes[i] = depthRes[i - 1] / glm::uvec2(2);
			inoutDepthOffset[i].y = inoutDepthOffset[i - 1].y + depthRes[i - 1].x;
			inoutDepthOffset[i].x = inoutDepthOffset[i - 1].y;
		}
		
	}
}
