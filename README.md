# osep-scripts
My OSEP scripts

## Python server
This server allows **downloading** via GET and **uploading** files via POST.

To upload files, you can use the **POST** method to `<URL>:<PORT>/<filename.ext>`.
```bash
# In the root folder 
python3 scripts/http-server/simple-http-post-server.py 8000
```

