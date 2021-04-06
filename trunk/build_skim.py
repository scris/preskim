#!/usr/bin/python

#
# This script is part of Skim.  Various paths are hardcoded near
# the top, along with other paths that are dependent on those.  The script
# builds, codesigns, and notarizes a zip compressed app bundle for release
# and create an appcast item for the release.
#

#
# SYNOPSIS
#   build_skim.sh [-i identity] [-u username] [-p password] [-o out] [-a zip|dmg|]
#
# OPTIONS
#   -i --identity
#       Codesign identity, not codesigned when empty
#   -u, --username
#       Username for notarization, not notarized when empty
#   -p, --password
#       Password for notarization, defaults to @keychain:AC_PASSWORD
#   -o, --out
#      Output directory for the final archive and appcast, defaults to the user's Desktop
#   -a, --archive
#      The type of archive the app bundle is wrapped in, the prepared disk image when empty
#

#
# Created by Adam Maxwell on 12/28/08.
#
# This software is Copyright (c) 2008-2021
# Adam Maxwell. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# - Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 
# - Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in
# the documentation and/or other materials provided with the
# distribution.
# 
# - Neither the name of Adam Maxwell nor the names of any
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

import os, sys, io, getopt
from subprocess import Popen, PIPE
from stat import ST_SIZE
import tarfile
from time import gmtime, strftime, localtime, sleep
import plistlib
import tempfile
from getpass import getuser

from Foundation import NSXMLDocument, NSUserDefaults, NSURL, NSXMLNodePrettyPrint, NSXMLNodePreserveCDATA

# determine the path based on the path of this program
SOURCE_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
assert len(SOURCE_DIR)
assert SOURCE_DIR.startswith("/")

# name of secure note in Keychain
KEY_NAME = "Skim Sparkle Key"

APPCAST_URL = "https://skim-app.sourceforge.io/skim.xml"

# create a private temporary directory
BUILD_ROOT = os.path.join("/tmp", "Skim-%s" % (getuser()))
try:
    # should already exist after the first run
    os.mkdir(BUILD_ROOT)
except Exception as e:
    assert os.path.isdir(BUILD_ROOT), "%s does not exist" % (BUILD_ROOT)

# derived paths
SYMROOT = os.path.join(BUILD_ROOT, "Products")
BUILD_DIR = os.path.join(SYMROOT, "Release")
BUILT_APP = os.path.join(BUILD_DIR, "Skim.app")
DERIVED_DATA_DIR = os.path.join(BUILD_ROOT, "DerivedData")
PLIST_PATH = os.path.join(BUILT_APP, "Contents", "Info.plist")

def read_versions():

    # read CFBundleVersion, CFBundleShortVersionString, LSMinimumSystemVersion and from Info.plist
    infoPlist = plistlib.readPlist(PLIST_PATH)
    assert infoPlist is not None, "unable to read Info.plist"
    newVersion = infoPlist["CFBundleVersion"]
    newVersionString = infoPlist["CFBundleShortVersionString"]
    minimumSystemVersion = infoPlist["LSMinimumSystemVersion"]
    assert newVersion is not None, "unable to read old version from Info.plist"
    assert newVersionString is not None, "unable to read old version from Info.plist"
    
    return newVersion, newVersionString , minimumSystemVersion

def clean_and_build():
    
    # clean and rebuild the Xcode project
    buildCmd = ["/usr/bin/xcodebuild", "clean", "-configuration", "Release", "-target", "Skim", "-scheme", "Skim", "-derivedDataPath", DERIVED_DATA_DIR, "SYMROOT=" + SYMROOT]
    nullDevice = open("/dev/null", "w")
    x = Popen(buildCmd, cwd=SOURCE_DIR)
    rc = x.wait()
    print("xcodebuild clean exited with status %s" % (rc))

    buildCmd = ["/usr/bin/xcodebuild", "-configuration", "Release", "-target", "Skim", "-scheme", "Skim", "-derivedDataPath", DERIVED_DATA_DIR, "SYMROOT=" + SYMROOT, "CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO"]
    nullDevice = open("/dev/null", "w")
    x = Popen(buildCmd, cwd=SOURCE_DIR)#, stdout=nullDevice, stderr=nullDevice)
    rc = x.wait()
    assert rc == 0, "xcodebuild failed"
    nullDevice.close()

def codesign(identity):
    
    print("codesign %s" % (BUILT_APP))
    
    sign_cmd = [os.path.join(SOURCE_DIR, "codesign_skim.sh"), identity, BUILT_APP]
    x = Popen(sign_cmd, cwd=SOURCE_DIR)
    rc = x.wait()
    print("codesign_skim.sh exited with status %s" % (rc))
    assert rc == 0, "code signing failed"
    
def notarize_dmg_or_zip(archive_path, username, password):
    
    print("notarize %s" % (archive_path))
    
    bundle_id = "net.sourceforce.skim-app.skim" + os.path.splitext(archive_path)[1]
    notarize_cmd = ["xcrun", "altool", "--notarize-app", "--primary-bundle-id", bundle_id, "--username", username, "--password",  password, "--output-format", "xml", "--file", archive_path]
    notarize_task = Popen(notarize_cmd, cwd=SOURCE_DIR, stdout=PIPE, stderr=PIPE)
    [output, error] = notarize_task.communicate()
    rc = notarize_task.returncode
    print("altool --notarize-app exited with status %s" % (rc))
    assert rc == 0, "notarization failed"
    
    output_stream = io.BytesIO(output)
    output_pl = plistlib.readPlist(output_stream)
    output_stream.close()
    sys.stderr.write("%s\n" % (output))
    assert "notarization-upload" in output_pl, "missing notarization-upload key in reply %s" % (output)
    
    request_uuid = output_pl["notarization-upload"]["RequestUUID"]
    
    while True:
    
        sleep(20)
        
        notarize_cmd = ["xcrun", "altool", "--notarization-info", request_uuid, "--username", username, "--password",  password, "--output-format", "xml"]
        notarize_task = Popen(notarize_cmd, cwd=SOURCE_DIR, stdout=PIPE, stderr=PIPE)
        [output, error] = notarize_task.communicate()
        rc = notarize_task.returncode
        assert rc == 0, "status request failed"
        
        output_stream = io.BytesIO(output)
        output_pl = plistlib.readPlist(output_stream)
        assert "notarization-info" in output_pl, "missing notarization-upload key in reply %s" % (output)
        status = output_pl["notarization-info"]["Status"]
            
        if status == "invalid":
            # open the URL
            log_url = output_pl["notarization-info"]["LogFileURL"]
            Popen(["/usr/bin/open", log_url])
            break
        elif status == "in progress":
            sys.stderr.write("notarization status not available yet for %s\n" % (request_uuid))
            continue
        else:
            # staple?
            sys.stderr.write("notarization succeeded\n")
            sys.stdout.write("%s\n" % (output))
                        
            log_url = output_pl["notarization-info"]["LogFileURL"]
            Popen(["/usr/bin/open", "-g", log_url])
            
            break

def create_dmg_of_application(new_version_number, create_new):
    
    # Create a name for the dmg based on version number, instead
    # of date, since I sometimes want to upload multiple betas per day.
    final_dmg_name = os.path.join(BUILD_DIR, os.path.splitext(os.path.basename(BUILT_APP))[0] + "-" + new_version_number + ".dmg")
    
    temp_dmg_path = os.path.join(BUILD_ROOT, "Skim.dmg")
    # remove temp image from a previous run
    if os.path.exists(temp_dmg_path):
        os.unlink(temp_dmg_path)
    
    nullDevice = open("/dev/null", "w")
    
    if create_new:
        print("wrap %s in disk image" % (BUILT_APP))
        
        cmd = ["/usr/bin/hdiutil", "create", "-fs", "HFS+", "-srcfolder", BUILT_APP, temp_dmg_path]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        assert rc == 0, "hdiutil create failed"
    else:
        # template image in source folder
        zip_dmg_name = os.path.join(SOURCE_DIR, "Skim.dmg.zip")
        
        # temporary volume
        dst_volume_name = "/Volumes/Skim"
        
        print("wrap %s in disk image from %s" % (BUILT_APP, zip_dmg_name))
        
        # see if this file already exists and bail
        assert not os.path.exists(final_dmg_name), "%s exists" % (final_dmg_name)
        
        # see if a volume is already mounted or a
        # previous cp operation was botched
        assert not os.path.exists(dst_volume_name), "%s exists" % (dst_volume_name)
        
        # stored zipped in svn, so unzip if needed
        # pass o to overwrite, or unzip waits for stdin
        # when trying to unpack the resource fork/EA
        
        nullDevice = open("/dev/null", "w")
        print("unzipping disk image %s to %s" % (zip_dmg_name, BUILD_ROOT))
        cmd = ["/usr/bin/unzip", "-uo", zip_dmg_name, "-d", BUILD_ROOT]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        assert rc == 0, "failed to unzip %s" % (zip_dmg_name)
        
        # mount image
        print("mounting disk image %s" % (temp_dmg_path))
        cmd = ["/usr/bin/hdiutil", "attach", "-nobrowse", "-noautoopen", temp_dmg_path]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        assert rc == 0, "failed to mount %s" % (temp_dmg_path)
        
        # use cp to copy all files
        print("copying build product from %s to %s" % (BUILT_APP, dst_volume_name))
        cmd = ["/bin/cp", "-R", BUILT_APP, dst_volume_name]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        assert rc == 0, "failed to copy %s" % (BUILT_APP)
        
        # tell finder to set the icon position
        print("moving build product in disk image")
        cmd = ["/usr/bin/osascript", "-e", """tell application "Finder" to set the position of application file "Skim.app" of disk named "Skim" to {90, 206}"""]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        assert rc == 0, "Finder failed to set position"
        
        # data is copied, so unmount the volume, we may need to wait when the volume is in use
        n_tries = 0
        print("ejecting disk image %s" % (dst_volume_name))
        cmd = ["/usr/sbin/diskutil", "eject", dst_volume_name]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        rc = x.wait()
        while rc != 0:
            assert n_tries < 12, "failed to eject %s" % (dst_volume_name)
            n_tries += 1
            sleep(5)
            x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
            rc = x.wait()
        
        # resize image to fit
        print("resizing disk image %s" % (temp_dmg_path))
        cmd = ["/usr/bin/hdiutil", "resize", temp_dmg_path]
        x = Popen(cmd, stdout=PIPE, stderr=nullDevice)
        size = x.communicate()[0].split(None, 1)[0]
        cmd = ["/usr/bin/hdiutil", "resize", "-size", size + "b", temp_dmg_path]
        x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
        assert rc == 0, "failed to resize  %s" % (temp_dmg_path)
    
    # convert image to read only and compress
    print("converting disk image %s to read only disk image at %s" % (temp_dmg_path, final_dmg_name))
    cmd = ["/usr/bin/hdiutil", "convert", temp_dmg_path, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", final_dmg_name]
    x = Popen(cmd, stdout=nullDevice, stderr=nullDevice)
    rc = x.wait()
    assert rc == 0, "hdiutil convert failed"
    
    nullDevice.close()
    os.unlink(temp_dmg_path)
    
    return final_dmg_name

def create_zip_of_application(new_version_number):
    
    # Create a name for the zip file based on version number, instead
    # of date, since I sometimes want to upload multiple betas per day.
    final_zip_name = os.path.join(BUILD_DIR, os.path.splitext(os.path.basename(BUILT_APP))[0] + "-" + new_version_number + ".zip")
    
    print("zip %s" % (BUILT_APP))
    nullDevice = open("/dev/null", "w")
    cmd = ["/usr/bin/ditto", "-c", "-k", "--keepParent", BUILT_APP, final_zip_name]
    x = Popen(cmd)
    rc = x.wait()
    assert rc == 0, "zip creation failed"
    
    return final_zip_name 

def keyFromSecureNote():
    
    # see http://www.entropy.ch/blog/Developer/2008/09/22/Sparkle-Appcast-Automation-in-Xcode.html
    pwtask = Popen(["/usr/bin/security", "find-generic-password", "-g", "-s", KEY_NAME], stdout=PIPE, stderr=PIPE)
    [output, error] = pwtask.communicate()
    pwoutput = output + error

    # notes are evidently stored as archived RTF data, so find start/end markers
    start = pwoutput.find("-----BEGIN DSA PRIVATE KEY-----")
    stopString = "-----END DSA PRIVATE KEY-----"
    stop = pwoutput.find(stopString)

    assert start is not -1 and stop is not -1, "failed to find DSA key in secure note"

    key = pwoutput[start:stop] + stopString
    
    # replace RTF end-of-lines
    key = key.replace("\\134\\012", "\n")
    key = key.replace("\\012", "\n")
    
    return key
    
def signature_and_size(archive_path):
    
    # write to a temporary file that's readably only by owner; minor security issue here since
    # we have to use a named temp file, but it's better than storing unencrypted key
    keyFile = tempfile.NamedTemporaryFile()
    keyFile.write(keyFromSecureNote())
    keyFile.flush()
    
    # now run the signature for Sparkle...
    sha_task = Popen(["/usr/bin/openssl", "dgst", "-sha1", "-binary"], stdin=open(archive_path, "rb"), stdout=PIPE)
    dss_task = Popen(["/usr/bin/openssl", "dgst", "-dss1", "-sign", keyFile.name], stdin=sha_task.stdout, stdout=PIPE)
    b64_task = Popen(["/usr/bin/openssl", "enc", "-base64"], stdin=dss_task.stdout, stdout=PIPE)
    
    # now compute the variables we need for writing the new appcast
    appcastSignature = b64_task.communicate()[0].strip()
    fileSize = str(os.stat(archive_path)[ST_SIZE])
    
    return appcastSignature, fileSize
    
def write_appcast(newVersion, newVersionString, minimumSystemVersion, archive_path, outputPath):
    
    print("create Sparkle appcast for %s" % (archive_path))
    
    appcastSignature, fileSize = signature_and_size(archive_path)
    download_url = "https://sourceforge.net/projects/skim/files/Skim/Skim-" + newVersionString + "/" + os.path.basename(archive_path) + "/download"
    appcastDate = strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime())
    if archive_path.endswith("dmg"):
        type = "application/x-apple-diskimage"
    else:
        type = "application/zip"
    
    # creating this from a string is easier than manipulating NSXMLNodes...
    newItemString = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <item>
            <title>Version """ + newVersionString + """</title>
            <description>
            <![CDATA[
<h1>Version ${VERSION}</h1>

<h2>New Features</h2>
<ul>
<li></li>
</ul>

<h2>Bugs Fixed</h2>
<ul>
<li></li>
</ul>
            ]]>
            </description>
            <pubDate>""" + appcastDate + """</pubDate>
            <sparkle:minimumSystemVersion>""" + minimumSystemVersion + """</sparkle:minimumSystemVersion>
            <enclosure url=\"""" + download_url + """\" sparkle:version=\"""" + newVersion + """\" sparkle:shortVersionString=\"""" + newVersionString + """\" length=\"""" + fileSize + """\" type=\"""" + type + """\" sparkle:dsaSignature=\"""" + appcastSignature + """\" />
        </item>
    </channel>
</rss>
"""
    
    # read from the source directory
    appcastURL = NSURL.URLWithString_(APPCAST_URL)
    
    # xml doc from the current appcast
    (oldDoc, error) = NSXMLDocument.alloc().initWithContentsOfURL_options_error_(appcastURL, NSXMLNodePreserveCDATA, None)
    assert oldDoc is not None, error
    
    # xml doc from the new appcast string
    (newDoc, error) = NSXMLDocument.alloc().initWithXMLString_options_error_(newItemString, NSXMLNodePreserveCDATA, None)
    assert newDoc is not None, error
    
    # get an arry of the current item titles
    (oldTitles, error) = oldDoc.nodesForXPath_error_("//item/title", None)
    assert oldTitles.count > 0, "oldTitles had no elements"
    
    # now get the title we just created
    (newTitles, error) = newDoc.nodesForXPath_error_("//item/title", None)
    assert newTitles.count() is 1, "newTitles must have a single element"
    
    # easy test to avoid duplicating items
    if oldTitles.containsObject_(newTitles.lastObject()) is False:

        # get the parent node we'll be inserting to
        (parentChannel, error) = oldDoc.nodesForXPath_error_("//channel", None)
        assert parentChannel.count() is 1, "channel count must be one"
        parentChannel = parentChannel.lastObject()
        
        # now get the new node
        (newNodes, error) = newDoc.nodesForXPath_error_("//item", None)
        assert newNodes is not None, error
        
        # insert a copy of the new node
        parentChannel.insertChild_atIndex_(newNodes.lastObject().copy(), 0)
        
        # write to user Desktop
        appcastPath = os.path.join(outputPath , "skim.xml")
        
        # write to NSData, since pretty printing didn't work with NSXMLDocument writing
        oldDoc.XMLDataWithOptions_(NSXMLNodePrettyPrint).writeToFile_atomically_(appcastPath, True)
        
    else:
        
        appcastPath = os.path.join(outputPath , "Skim-" + newVersionString + ".xml")
        appcastFile = open(appcastPath, "w")
        appcastFile.write(newItemString)
        appcastFile.close()

def get_options():
    
    identity = ""
    username = ""
    password = "@keychain:AC_PASSWORD"
    out = os.path.join(os.getenv("HOME"), "Desktop")
    archive = ""
    
    try:
        opts, args = getopt.getopt(sys.argv[1:], "i:u:p:o:a:", ["identity=", "username=", "password=", "out=", "archive="])
    except:
        sys.stderr.write("error reading options\n")
    
    for opt, arg in opts:
        if opt in ["-i", "--identity"]:
            identity = arg
        elif opt in ["-u", "--username"]:
            username = arg
        elif opt in ["-p", "--password"]:
            password = arg
        elif opt in ["-o", "--out"]:
            out = arg
        elif opt in ["-a", "--archive"]:
            archive = arg
    
    return identity, username, password, out, archive

if __name__ == '__main__':
    
    identity, username, password, out, archive = get_options()
    
    clean_and_build()
    
    if identity != "":
        codesign(identity)
    else:
        sys.stderr.write("warning: built product will not be codesigned\n")
    
    new_version, new_version_string, minimum_system_version = read_versions()
    
    if archive == "zip":
        archive_path = create_zip_of_application(new_version_string)
    else:
        archive_path = create_dmg_of_application(new_version_string, archive == "dmg")
    
    # will bail if any part fails
    if username != "":
        notarize_dmg_or_zip(archive_path, username, password)
        
        if archive_path.endswith("dmg"):
            # xcrun stapler staple Skim.app-1.4.dmg
            x = Popen(["xcrun", "stapler", "staple", archive_path])
            rc = x.wait()
            assert rc == 0, "stapler failed"
        else:
            # staple the application, then delete the zip we notarized
            # and make a new zip of the stapled application, because stapler
            # won't staple a damn zip file https://developer.apple.com/forums/thread/115670
            x = Popen(["xcrun", "stapler", "staple", BUILT_APP])
            rc = x.wait()
            assert rc == 0, "stapler failed"
            os.unlink(archive_path)
            archive_path = create_zip_of_application(new_version_string)
    else:
            sys.stderr.write("warning: built product will not be notarized\n")
    
    try:
        # probably already exists
        os.mkdirs(out)
    except Exception as e:
        assert os.path.isdir(out), "%s does not exist" % (out)
    
    write_appcast(new_version, new_version_string, minimum_system_version, archive_path, out)
    
    target_path = os.path.join(out, os.path.basename(archive_path))
    if (os.path.exists(target_path)):
        os.unlink(target_path)
    os.rename(archive_path, target_path)
