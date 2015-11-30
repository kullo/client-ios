#!/usr/bin/env python3

import json
import os
import subprocess

source_file = "kullo_app_icon.svg"
export_dir = "export"
appicon_dir = os.path.join(export_dir, 'AppIcon.appiconset')
appstore_dir = os.path.join(export_dir, 'AppStore')

sizes = {
    'appstore': {
        'default': {
            'size': 1024,
            'scales': [1],
        },
    },
    'homescreen': {
        'iphone': {
            'size': 60,
            'scales': [2, 3],
        },
        # We ignore ipad pro @2x 167x167 here
        'ipad': {
            'size': 76,
            'scales': [1, 2],
        },
    },
    'spotlight': {
        # We ignore Phone 6s and iPhone 6 @2x 120x120 here
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
        # We ignore Phone 6s and iPhone 6 @2x 120x120 here
        'iphone': {
            'size': 29,
            'scales': [2, 3],
        },
        'ipad': {
            'size': 29,
            'scales': [1, 2],
        }
    }
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

try:
    os.makedirs(appstore_dir)
except OSError:
    print("Directory '%s' already exists" % appicon_dir)

for usage in sorted(sizes):
    for device in sorted(sizes[usage]):
        for scale in sorted(sizes[usage][device]['scales']):
            pt = sizes[usage][device]['size']
            px = pt * scale
            filename = "%s_%s@%sx.png" % (usage, device, scale)
            print("%s: %d ..." % (filename, px))

            if usage != 'appstore':
                entry = {
                    'size': "%dx%d" % (pt, pt),
                    "idiom" : device,
                    "filename" : filename,
                    "scale" : "%sx" % scale
                }
                contents['images'].append(entry)

            if usage == 'appstore':
                outfile = os.path.join(appstore_dir, filename)
            else:
                outfile = os.path.join(appicon_dir, filename)

            cmd = [
                '/usr/bin/inkscape',
                '--without-gui',
                "--file=" + source_file,
                "--export-png=" + outfile,
                "--export-width=" + str(px)
            ]
            subprocess.call(cmd)

with open(os.path.join(appicon_dir, "Contents.json"), "w") as f:
    f.write(json.dumps(contents, sort_keys=True, indent=2))

