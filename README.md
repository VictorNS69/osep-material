# osep-scripts
My OSEP scripts

## Python server
This server allows **downloading** via GET and **uploading** files via POST.

To upload files, you can use the **POST** method to `<URL>:<PORT>/<filename.ext>`.
```bash
# In the root folder 
python3 scripts/http-server/simple-http-post-server.py 8000
```

## Script to change all URLs
> [!NOTE]
> Please read [this](https://github.com/VictorNS69/osep-material/tree/main/scripts#ip-replacepy) before running `ip-replace.py`.

```bash
# In the root folder
scripts/ip-replace.py --search 'http://<URL>:<PORT>' --replace http://192.168.235.130:8000 --backup-dir ./backup --mode direct
```
