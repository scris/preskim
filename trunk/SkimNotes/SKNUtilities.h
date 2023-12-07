//
//  SKNUtilities.h
//  SkimNotes
//
//  Created by Christiaan Hofman on 7/17/08.
/*
 This software is Copyright (c) 2008-2023
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

/*!
    @abstract   Returns an array of Skim notes from the data.
    @discussion This is used to write a default Skim text notes representation when not provided for writing.
    @param      data The data object to extract the notes from, either an archive or plist data.
    @result     An array of dictionaries containing Skim notes properties.
*/
extern NSArray<NSDictionary<NSString *, id> *> * _Nullable SKNSkimNotesFromData(NSData * _Nullable data);

/*!
    @abstract   Returns data for the Skim notes.
    @discussion Can return the data as archived data, or as universal plist data.
    @param      notes An array of dictionaries containing Skim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @param      asPlist Whether to create universal plist data rather than archived data.  Always returns plist data on iOS.
    @result     A data representation of the notes.
*/
extern NSData * _Nullable SKNDataFromSkimNotes(NSArray<NSDictionary<NSString *, id> *> * _Nullable notes, BOOL asPlist);

/*!
    @abstract   Returns a string representation of Skim notes.
    @discussion This is used to write a default Skim text notes representation when not provided for writing.
    @param      noteDicts An array of dictionaries containing Skim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @result     A string representation of the notes.
*/
extern NSString * _Nullable SKNSkimTextNotes(NSArray<NSDictionary<NSString *, id> *> * _Nullable noteDicts);

/*!
    @abstract   Returns an RTF data representation of Skim notes.
    @discussion This is used to write a default Skim RTF notes representation when not provided for writing.
    @param      noteDicts An array of dictionaries containing Skim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @result     An RTF data representation of the notes.
*/
extern NSData * _Nullable SKNSkimRTFNotes(NSArray<NSDictionary<NSString *, id> *> * _Nullable noteDicts);
