extern void status_save_range(void);
volatile unsigned char scavenged_values[4];
volatile unsigned short corpus_result;
int main(void) {
  status_save_range();
  corpus_result = scavenged_values[0] == 6 && scavenged_values[1] == 6 &&
                         scavenged_values[2] == 7 && scavenged_values[3] == 1
                     ? 0x600d : 0xbad;
  for (;;) {}
}
