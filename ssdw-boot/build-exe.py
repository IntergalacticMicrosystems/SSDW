import py2exe
py2exe.freeze(
    console=[{
        "script": "ssdw-boot.py"}], 
    options={
        "py2exe":{"bundle_files": 2}}
)