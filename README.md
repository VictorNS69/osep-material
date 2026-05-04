# My OSEP Material
This is a repository I built while working on my OSEP certification.

Much of the content consists of references to or modifications of other authors' work. I have tried to cite all or nearly all of them.


Certification link: <https://www.offsec.com/courses/pen-300/>

## Python server
This server allows **downloading** via GET and **uploading** files via POST.

To upload files, you can use the **POST** method to `<URL>:<PORT>/<filename.ext>`.
```bash
# In the root folder 
python3 scripts/http-server/simple-http-post-server.py 80
```

## Script to change all URLs
> [!NOTE]
> Please read [this](https://github.com/VictorNS69/osep-material/tree/main/scripts#ip-replacepy) before running `ip-replace.py`.

```bash
# In the root folder
scripts/ip-replace.py --search '192.168.45.1' --replace-url '192.168.45.223' --backup-dir . --no-confirm
```

## Interesting links
- https://www.emmanuelsolis.com/osep.html
- https://github.com/Sh3lldon/FullBypass
- https://github.com/r4ulcl/Mythic-OSEP-CheatSheet
- https://github.com/In3x0rabl3/OSEP
- https://github.com/B4l3rI0n/OSEP
- https://github.com/lsecqt/OffensiveCpp
- https://github.com/wsummerhill/Malware_Weaponization
- https://github.com/chvancooten/OSEP-Code-Snippets
- https://github.com/JoasASantos/OSCE3-Complete-Guide
- https://github.com/Extravenger/OSEPlayground
- https://github.com/hackinaggie/OSEP-Tools-v2

And many more :)
  
