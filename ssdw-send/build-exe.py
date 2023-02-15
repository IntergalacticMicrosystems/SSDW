import py2exe
py2exe.freeze(
    console=[{
        "script": "ssdw-send.py"}], 
    options={
        "py2exe":{"bundle_files": 2}}
)