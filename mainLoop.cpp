void RadianceCascade::Update(glm::vec3 sunDir, unsigned int frame) {
	genCascade.setVal<float>("sunDir", sun.sunDir.x, sun.sunDir.y, sun.sunDir.z);
	genCascade.setVal<unsigned int>("frame", frame);

	
	
	for (unsigned int i = 0; i < NUM_CASCADE; i++) {
		downSampleDepth.setVal<unsigned int>("inOffset", inoutDepthOffset[i].x);
		downSampleDepth.setVal<unsigned int>("outOffset", inoutDepthOffset[i].y);
		downSampleDepth.Dispatch(glm::max(depthRes[i].x / 8, unsigned int(1)), glm::max(depthRes[i].y / 8, unsigned int(1)), 1);
		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
	}
	

	for (int i = NUM_CASCADE - 1; i >= 0; i--) {
		unsigned int ui = i;

		genCascade.setVal<unsigned int>("cascadeIndex", ui);
		genCascade.setVal<float>("rayStart", rayIntervals[i].x);
		genCascade.setVal<float>("rayEnd", rayIntervals[i].y);
		genCascade.setVal<unsigned int>("depthOffset", inoutDepthOffset[i].x);
		genCascade.setVal<unsigned int>("depthOffset2", inoutDepthOffset[i+1].x);

		if (i >= LOWEST_CASCADE) {
			genCascade.Dispatch(CASCADE_0_DIM * res.x / 8, CASCADE_0_DIM * res.y / 8, 1);
			glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

			
		}

	}
	glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
}
