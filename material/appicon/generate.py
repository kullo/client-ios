#!/usr/bin/env python3

import json
import os
import subprocess

source_file = os.path.abspath("kullo_app_icon.svg")
export_dir = os.path.abspath("export")
appicon_dir = os.path.join(export_dir, 'AppIcon.appiconset')
appstore_dir = os.path.join(export_dir, 'AppStore')

sizes = {
    'appstore': {
        'ios-marketing': {
            'size': 1024,
            'scales': [1],
        },
    },
    'homescreen': {
        'iphone': {
            'size': 60,
            'scales': [2, 3],
        },
        'ipad': {
            'size': 76,
            'scales': [1, 2],
        },
        'ipad-pro': {
            'iconset_device': 'ipad',
            'size': 83.5,
            'scales': [2],
        },
    },
    'spotlight': {
        'iphone': {
            'size': 40,
            'scales': [2, 3],
        },
        'ipad': {
            'size': 40,
            'scales': [1, 2],
        }
    },
    'settings': {
        'iphone': {
            'size': 29,
            'scales': [2, 3],
        },
        'ipad': {
            'size': 29,
            'scales': [1, 2],
        }
    },
    'notifications': {
        'iphone': {
            'size': 20,
            'scales': [2, 3],
        },
        'ipad': {
            'size': 20,
            'scales': [1, 2],
        }
    },
}

contents = {
  "info" : {
    "version" : 1,
    "author" : "xcode",
  },
  "images" : [],
}

try:
    os.makedirs(appicon_dir)
except OSError:
    print("Directory '%s' already exists" % appicon_dir)

for usage in sorted(sizes):
    for device in sorted(sizes[usage]):
        for scale in sorted(sizes[usage][device]['scales']):
            pt = sizes[usage][device]['size']
            px = pt * scale
            filename = "%s_%s@%sx.png" % (usage, device, scale)
            print("%s: %d ..." % (filename, px))

            entry = {
                'size': "%dx%d" % (pt, pt),
                "idiom" : sizes[usage][device].get("iconset_device", device),
                "filename" : filename,
                "scale" : "%sx" % scale
            }
            contents['images'].append(entry)

            outfile = os.path.join(appicon_dir, filename)

            cmd = [
                # brew cask install inkscape
                '/usr/local/bin/inkscape',
                '--without-gui',
                "--file=" + source_file,
                "--export-png=" + outfile,
                "--export-width=" + str(px)
            ]
            subprocess.call(cmd)

with open(os.path.join(appicon_dir, "Contents.json"), "w") as f:
    f.write(json.dumps(contents, sort_keys=True, indent=2))

