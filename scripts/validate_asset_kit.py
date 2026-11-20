#!/usr/bin/env python3
"""Validate generated assets through a disposable Godot project, not a game test.

Requires Godot on PATH. Copies materials and GLBs into a temporary directory,
imports them, then loads resources and instantiates each model. Does not claim
that gameplay, visual parity or all GPU renderer paths have been tested.
"""
from pathlib import Path
import json
import shutil
import struct
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
CHECK='''extends SceneTree

func _initialize():
    var count = 0
    var failures = []
    for filename in DirAccess.get_files_at("res://art/materials"):
        if filename.ends_with(".tres") or filename.ends_with(".gdshader"):
            var path = "res://art/materials/" + filename
            var resource = load(path)
            if resource == null:
                failures.append(path)
            else:
                if resource is Shader:
                    resource.get_shader_uniform_list()
                count += 1
    for filename in DirAccess.get_files_at("res://art/models"):
        if filename.ends_with(".glb"):
            var path = "res://art/models/" + filename
            var packed = load(path)
            if packed == null or not packed is PackedScene:
                failures.append(path)
            else:
                var instance = packed.instantiate()
                if not instance is Node3D:
                    failures.append(path)
                instance.free()
                count += 1
    print("CINDERTRAIL_RESOURCE_CHECK " + JSON.stringify({"loaded":count,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
'''

def main():
    godot=shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Godot is required for this validation.")
    report={"godot_version":subprocess.check_output([godot,"--version"],text=True).strip(),
            "kind":"headless resource import/load and GLB instantiation", "renderer":"gl_compatibility headless; no visual GPU parity test", "models":{}}
    for p in sorted((ROOT/"art/models").glob("*.glb")):
        magic,version,length=struct.unpack("<4sII",p.read_bytes()[:12])
        if magic != b"glTF" or version != 2 or length != p.stat().st_size:
            raise RuntimeError("Invalid GLB header: "+str(p))
        report["models"][p.name]={"glb_version":version,"bytes":length}
    with tempfile.TemporaryDirectory(prefix="cindertrail_asset_check_") as td:
        path=Path(td)
        (path/"project.godot").write_text('[application]\nconfig/name="Cindertrail asset validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        shutil.copytree(ROOT/"art/materials",path/"art/materials")
        (path/"art/models").mkdir(parents=True)
        for p in (ROOT/"art/models").glob("*.glb"):
            shutil.copy2(p,path/"art/models"/p.name)
        (path/"check.gd").write_text(CHECK)
        imported=subprocess.run([godot,"--headless","--editor","--path",str(path),"--import"],text=True,capture_output=True,timeout=120)
        loaded=subprocess.run([godot,"--headless","--path",str(path),"--script","check.gd"],text=True,capture_output=True,timeout=60)
        report.update(import_exit=imported.returncode,load_exit=loaded.returncode)
        combined=imported.stdout+imported.stderr+loaded.stdout+loaded.stderr
        report["resource_result"]=next((json.loads(line.split("CINDERTRAIL_RESOURCE_CHECK ",1)[1]) for line in loaded.stdout.splitlines() if "CINDERTRAIL_RESOURCE_CHECK " in line),None)
        report["errors"]=[line for line in combined.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
        report["passed"]=imported.returncode==0 and loaded.returncode==0 and not report["errors"] and report["resource_result"] is not None
        (ROOT/"art/materials/VALIDATION.json").write_text(json.dumps(report,indent=2)+"\n")
        print(json.dumps(report,indent=2))
        if not report["passed"]:
            print(combined[-12000:])
            raise SystemExit(1)

if __name__=="__main__":main()
