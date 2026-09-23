# NInfer 5090 laptop version for Windows

This repo offers ready configuration for running NInfer on a laptop version of 5090, which has 24GB of VRAM compared to desktop's 32GB.

The main differences from the original repo are the following.

1. Changed the port to be the same for both models
2. Changed the context to 65k for the mtp version
3. Changed the context to 45k for the dflash2 version

The MTP4 version can fit more context, but with significantly reduced tokens per second.

Local testing results:

| Profile | Context |          Decode | Acceptance |   TTFT |
| ------- | ------: | --------------: | ---------: | -----: |
| MTP4    |  65,536 |  **89.7 tok/s** |      58.9% | 432 ms |
| DFlash2 |  45,056 | **131.6 tok/s** |      48.9% | 394 ms |


This setup worked with an initial windows usage of ~1600MB of vram (check with nvidia-smi.exe)

# Setup

Follow the steps described in https://github.com/headpiece747/ninfer-5090-windows

This repo assumes this option for the model: `qwen3_8_27b_nvfp4qat.v3.ninfer` and the release [1.1.0](https://github.com/headpiece747/ninfer-5090-windows/releases/tag/v1.1.0) of the above mentioned repo.
