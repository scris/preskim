//
//  NSFileManager_SKNExtensions.h
//  SkimNotes
//
//  Created by Christiaan Hofman on 6/15/08.
/*
 This software is Copyright (c) 2008
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

/*!
    @header      
    @abstract    An <code>NSFileManager</code> category to read and write Preskim notes.
    @discussion  This header file provides API for an <code>NSFileManager</code> category to read and write Preskim notes.
*/
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @enum        SKNSkimNotesWritingOptions
 @abstract    Options for writing Preskim notes.
 @discussion  These options can be passed to the main methods for writing Preskim notes to extended attributes or to file.
 @constant    SKNSkimNotesWritingPlist      Write plist data rather than archived data.  Always implied on iOS.
 @constant    SKNSkimNotesWritingSyncable   Hint to add a syncable flag to the attribute names if available, when writing to extended attributes.
 */
enum {
    SKNSkimNotesWritingPlist = 1 << 0,
    SKNSkimNotesWritingSyncable = 1 << 1
};
typedef NSInteger SKNSkimNotesWritingOptions;

/*!
    @abstract    Provides methods to access Preskim notes in extended attributes or PDF bundles.
    @discussion  This category is the main interface to read and write Preskim notes from and to files and extended attributes of files.
*/
@interface NSFileManager (SKNExtensions)

/*!
    @abstract   Reads Preskim notes as an array of property dictionaries from the extended attributes of a file.
    @discussion Reads the data from the extended attributes of the file and convert.
    @param      aURL The URL for the file to read the Preskim notes from.
    @param      outError If there is an error reading the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     An array of dictionaries with Preskim note properties, an empty array if no Preskim notes were found, or <code>nil</code> if there was an error reading the Preskim notes.
*/
- (nullable NSArray<NSDictionary<NSString *, id> *> *)readSkimNotesFromExtendedAttributesAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads text Preskim notes as a string from the extended attributes of a file.
    @discussion Reads the data from the extended attributes of the file and unarchives it using <code>NSKeyedUnarchiver</code>.
    @param      aURL The URL for the file to read the text Preskim notes from.
    @param      outError If there is an error reading the text Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     A string representation of the Preskim notes, an empty string if no text Preskim notes were found, or <code>nil</code> if there was an error reading the text Preskim notes.
*/
- (nullable NSString *)readPreskimTextNotesFromExtendedAttributesAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads rich text Preskim notes as RTF data from the extended attributes of a file.
    @discussion Reads the data from the extended attributes of the file.
    @param      aURL The URL for the file to read the RTF Preskim notes from.
    @param      outError If there is an error reading the RTF Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     <code>NSData</code> for an RTF representation of the Preskim notes, an empty <code>NSData</code> object if no RTF Preskim notes were found, or <code>nil</code> if there was an error reading the RTF Preskim notes.
*/
- (nullable NSData *)readPreskimRTFNotesFromExtendedAttributesAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads Preskim notes as an array of property dictionaries from the contents of a PDF bundle.
    @discussion Reads the data from a bundled file in the PDF bundle with the proper .pskn extension.
    @param      aURL The URL for the PDF bundle to read the Preskim notes from.
    @param      outError If there is an error reading the Preskim notes, upon return contains an NSError object that describes the problem.
    @result     An array of dictionaries with Preskim note properties, an empty array if no Preskim notes were found, or <code>nil</code> if there was an error reading the Preskim notes.
*/
- (nullable NSArray<NSDictionary<NSString *, id> *> *)readSkimNotesFromPDFBundleAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads text Preskim notes as a string from the contents of a PDF bundle.
    @discussion Reads the data from a bundled file in the PDF bundle with the proper .txt extension.
    @param      aURL The URL for the PDF bundle to read the text Preskim notes from.
    @param      outError If there is an error reading the text Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     A string representation of the Preskim notes, an empty string if no text Preskim notes were found, or <code>nil</code> if there was an error reading the text Preskim notes.
*/
- (nullable NSString *)readPreskimTextNotesFromPDFBundleAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads rich text Preskim notes as RTF data from the contents of a PDF bundle.
    @discussion Reads the data from a bundled file in the PDF bundle with the proper .rtf extension.
    @param      aURL The URL for the PDF bundle to read the RTF Preskim notes from.
    @param      outError If there is an error reading the RTF Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     <code>NSData</code> for an RTF representation of the Preskim notes, an empty <code>NSData</code> object if no RTF Preskim notes were found, or <code>nil</code> if there was an error reading the RTF Preskim notes.
*/
- (nullable NSData *)readPreskimRTFNotesFromPDFBundleAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Reads Preskim notes as an array of property dictionaries from the contents of a .pskn file.
    @discussion Reads data from the file and unarchives it using NSKeyedUnarchiver.
    @param      aURL The URL for the .pskn file to read the Preskim notes from.
    @param      outError If there is an error reading the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     An array of dictionaries with Preskim note properties, an empty array if no Preskim notes were found, or <code>nil</code> if there was an error reading the Preskim notes.
*/
- (nullable NSArray<NSDictionary<NSString *, id> *> *)readSkimNotesFromPreskimFileAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Writes Preskim notes passed as an array of property dictionaries to the extended attributes of a file, as well as a defaultrepresentation for text Preskim notes and RTF Preskim notes.
 @discussion Calls <code>writeSkimNotes:textNotes:richTextNotes:toExtendedAttributesAtURL:options:error:</code> with nil <code>notesString</code> and <code>notesRTFData</code> and the <code>SKNSkimNotesWritingPlist<code> and <code>SKNSkimNotesWritingSyncable<code> options.
    @param      notes An array of dictionaries containing Preskim note properties, as returned by the properties of a PDFAnnotation.
    @param      aURL The URL for the file to write the Preskim notes to.
    @param      outError If there is an error writing the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     Returns <code>YES</code> if writing out the Preskim notes was successful; otherwise returns <code>NO</code>.
*/
- (BOOL)writeSkimNotes:(nullable NSArray<NSDictionary<NSString *, id> *> *)notes toExtendedAttributesAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Writes Preskim notes passed as an array of property dictionaries to the extended attributes of a file, as well as text Preskim notes and RTF Preskim notes.  The array is converted to <code>NSData</code> using <code>NSKeyedArchiver</code>.
 @discussion Calls <code>writeSkimNotes:textNotes:richTextNotes:toExtendedAttributesAtURL:options:error:</code> with the <code>SKNSkimNotesWritingPlist<code> and <code>SKNSkimNotesWritingSyncable<code> options.
    @param      notes An array of dictionaries containing Preskim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @param      notesString A text representation of the Preskim notes.  When <code>nil</code>, a default representation will be generated from notes.
    @param      notesRTFData An RTF data representation of the Preskim notes.  When <code>nil</code>, a default representation will be generated from notes.
    @param      aURL The URL for the file to write the Preskim notes to.
    @param      outError If there is an error writing the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     Returns <code>YES</code> if writing out the Preskim notes was successful; otherwise returns <code>NO</code>.
*/
- (BOOL)writeSkimNotes:(nullable NSArray<NSDictionary<NSString *, id> *> *)notes textNotes:(nullable NSString *)notesString richTextNotes:(nullable NSData *)notesRTFData toExtendedAttributesAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
 @abstract   Writes Preskim notes passed as an array of property dictionaries to the extended attributes of a file, as well as text Preskim notes and RTF Preskim notes.  The array is converted to <code>NSData</code> using <code>NSKeyedArchiver</code> or as plist data, depending on the options.
 @discussion This writes three types of Preskim notes to the extended attributes to the file located through <code>aURL</code>.
 @param      notes An array of dictionaries containing Preskim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
 @param      notesString A text representation of the Preskim notes.  When <code>nil</code>, a default representation will be generated from notes.
 @param      notesRTFData An RTF data representation of the Preskim notes.  When <code>nil</code>, a default representation will be generated from notes.
 @param      aURL The URL for the file to write the Preskim notes to.
 @param      options The write options to use.
 @param      outError If there is an error writing the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
 @result     Returns <code>YES</code> if writing out the Preskim notes was successful; otherwise returns <code>NO</code>.
 */
- (BOOL)writeSkimNotes:(nullable NSArray<NSDictionary<NSString *, id> *> *)notes textNotes:(nullable NSString *)notesString richTextNotes:(nullable NSData *)notesRTFData toExtendedAttributesAtURL:(NSURL *)aURL options:(SKNSkimNotesWritingOptions)options error:(NSError **)outError;

/*!
    @abstract   Writes Preskim notes passed as an array of property dictionaries to a .pskn file.
    @discussion Calls <code>writeSkimNotes:toPreskimFileAtURL:options:error:</code> with the <code>SKNSkimNotesWritingPlist<code> options.
    @param      notes An array of dictionaries containing Preskim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @param      aURL The URL for the .pskn file to write the Preskim notes to.
    @param      outError If there is an error writing the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     Returns <code>YES</code> if writing out the Preskim notes was successful; otherwise returns <code>NO</code>.
*/
- (BOOL)writeSkimNotes:(nullable NSArray<NSDictionary<NSString *, id> *> *)notes toPreskimFileAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Writes Preskim notes passed as an array of property dictionaries to a .pskn file.  The array is converted to <code>NSData</code> using <code>NSKeyedArchiver</code> or as plist data, depending on the options.
    @discussion Writes the data to the file located by <code>aURL</code>.
    @param      notes An array of dictionaries containing Preskim note properties, as returned by the properties of a <code>PDFAnnotation</code>.
    @param      aURL The URL for the .pskn file to write the Preskim notes to.
    @param      options The write options to use.
    @param      outError If there is an error writing the Preskim notes, upon return contains an <code>NSError</code> object that describes the problem.
    @result     Returns <code>YES</code> if writing out the Preskim notes was successful; otherwise returns <code>NO</code>.
*/
- (BOOL)writeSkimNotes:(nullable NSArray<NSDictionary<NSString *, id> *> *)notes toPreskimFileAtURL:(NSURL *)aURL options:(SKNSkimNotesWritingOptions)options error:(NSError **)outError;

/*!
    @abstract   Returns the file URL for the file of a given type inside a PDF bundle.
    @discussion If more than one bundled files with the given extension exist in the PDF bundle, this will follow the naming rules followed by Preskim to find the best match.
    @param      extension The file extension for which to find a bundled file.
    @param      aURL The URL to the PDF bundle.
    @param      outError If there is an error getting the bundled file, upon return contains an <code>NSError</code> object that describes the problem.
    @result     A file URL to the bundled file inside the PDF bundle, or <code>nil</code> if no bundled file was found.
*/
- (nullable NSURL *)bundledFileURLWithExtension:(NSString *)extension inPDFBundleAtURL:(NSURL *)aURL error:(NSError **)outError;

/*!
    @abstract   Returns the full path for the file of a given type inside a PDF bundle.
    @discussion If more than one bundled files with the given extension exist in the PDF bundle, this will follow the naming rules followed by Preskim to find the best match. This method is deprecated.
    @param      extension The file extension for which to find a bundled file.
    @param      path The path to the PDF bundle.
    @param      outError If there is an error getting the bundled file, upon return contains an <code>NSError</code> object that describes the problem.
    @result     A full path to the bundled file inside the PDF bundle, or <code>nil</code> if no bundled file was found.
*/
- (nullable NSString *)bundledFileWithExtension:(NSString *)extension inPDFBundleAtPath:(NSString *)path error:(NSError **)outError;

@end

NS_ASSUME_NONNULL_END
