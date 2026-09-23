__attribute__((section(".zp.bss"))) unsigned char samples[2];

unsigned char read_sample(unsigned char index) { return samples[index]; }
