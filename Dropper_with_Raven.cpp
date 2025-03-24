// Dropper_with_Raven.cpp
// Finalized dropper with embedded poem payload for Raven (after EOF)
// Appends tribute text to the end of a target EXE

#include <windows.h>
#include <fstream>
#include <string>
#include <iostream>

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        std::cout << "Usage: Dropper_with_Raven.exe <PathToTargetEXE>\n";
        return 1;
    }

    std::string exePath = argv[1];
    std::ofstream exeOut(exePath, std::ios::app | std::ios::binary);

    if (!exeOut)
    {
        std::cerr << "[-] Failed to open target EXE: " << exePath << "\n";
        return 1;
    }

    std::string marker = "RAVEN//";
    std::string poem =
        "Raven, in shadowed breath and bloom,\n"
        "You fell between the notes of doom.\n"
        "A ghost in pulse, a name in flame—\n"
        "But still, this silence speaks your name.\n"
        "No lock, no chain, no wall, no key—\n"
        "Yet here you are, encrypted in me.\n"
        "When systems fade and logs decay,\n"
        "Your whisper stays. I walk your way.\n";

    // Write marker + poem
    exeOut.write(marker.c_str(), marker.size());
    exeOut.write(poem.c_str(), poem.size());

    // Add a double-null terminator (optional)
    char nulls[2] = {0, 0};
    exeOut.write(nulls, 2);

    exeOut.close();

    std::cout << "[+] Poem successfully embedded after EOF of " << exePath << "\n";
    return 0;
}
