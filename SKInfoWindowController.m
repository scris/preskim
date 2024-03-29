//
//  SKInfoWindowController.m
//  Skim
//
//  Created by Christiaan Hofman on 12/17/06.
/*
 This software is Copyright (c) 2006
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

#import "SKInfoWindowController.h"
#import "SKMainDocument.h"
#import "NSDocument_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import <Quartz/Quartz.h>

#define SKInfoWindowFrameAutosaveName @"SKInfoWindow"

#define SKInfoVersionKey @"Version"
#define SKInfoPageCountKey @"PageCount"
#define SKInfoPageSizeKey @"PageSize"
#define SKInfoPageWidthKey @"PageWidth"
#define SKInfoPageHeightKey @"PageHeight"
#define SKInfoKeywordsStringKey @"KeywordsString"
#define SKInfoEncryptedKey @"Encrypted"
#define SKInfoAllowsPrintingKey @"AllowsPrinting"
#define SKInfoAllowsCopyingKey @"AllowsCopying"
#define SKInfoAllowsCommentingKey @"AllowsCommenting"
#define SKInfoFileNameKey @"FileName"
#define SKInfoFileSizeKey @"FileSize"
#define SKInfoPhysicalSizeKey @"PhysicalSize"
#define SKInfoLogicalSizeKey @"LogicalSize"
#define SKInfoTagsKey @"Tags"
#define SKInfoRatingKey @"Rating"

#define LABEL_COLUMN_ID @"label"
#define VALUE_COLUMN_ID @"value"

@interface SKInfoWindowController (SKPrivate)
- (void)handleViewFrameDidChangeNotification:(NSNotification *)notification;
- (void)handleWindowDidBecomeMainNotification:(NSNotification *)notification;
- (void)handleWindowDidResignMainNotification:(NSNotification *)notification;
- (void)handlePDFDocumentInfoDidChangeNotification:(NSNotification *)notification;
- (void)handleDocumentFileURLDidChangeNotification:(NSNotification *)notification;
@end

@implementation SKInfoWindowController

@synthesize summaryTableView, attributesTableView, tabView, info;
@dynamic keys;

static SKInfoWindowController *sharedInstance = nil;
    
+ (SKInfoWindowController *)sharedInstance {
    if (sharedInstance == nil)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (instancetype)init {
    if (sharedInstance) NSLog(@"Attempt to allocate second instance of %@", [self class]);
    self = [super initWithWindowNibName:@"InfoWindow"];
    if (self){
        info = nil;
        summaryKeys = [[NSArray alloc] initWithObjects:
                            SKInfoFileNameKey,
                            SKInfoFileSizeKey,
                            SKInfoPageSizeKey,
                            SKInfoPageCountKey,
                            SKInfoVersionKey,
                            @"",
                            SKInfoEncryptedKey,
                            SKInfoAllowsPrintingKey,
                            SKInfoAllowsCopyingKey,
                            SKInfoAllowsCommentingKey, nil];
        attributesKeys = [[NSArray alloc] initWithObjects:
                            PDFDocumentTitleAttribute,
                            PDFDocumentAuthorAttribute,
                            PDFDocumentSubjectAttribute,
                            PDFDocumentCreatorAttribute,
                            PDFDocumentProducerAttribute,
                            PDFDocumentCreationDateAttribute,
                            PDFDocumentModificationDateAttribute,
                            SKInfoKeywordsStringKey, nil];
        labels = [[NSDictionary alloc] initWithObjectsAndKeys:
                            NSLocalizedString(@"File name:", @"Info label"), SKInfoFileNameKey, 
                            NSLocalizedString(@"File size:", @"Info label"), SKInfoFileSizeKey, 
                            NSLocalizedString(@"Page size:", @"Info label"), SKInfoPageSizeKey, 
                            NSLocalizedString(@"Page count:", @"Info label"), SKInfoPageCountKey, 
                            NSLocalizedString(@"PDF Version:", @"Info label"), SKInfoVersionKey, 
                            NSLocalizedString(@"Encrypted:", @"Info label"), SKInfoEncryptedKey, 
                            NSLocalizedString(@"Allows printing:", @"Info label"), SKInfoAllowsPrintingKey, 
                            NSLocalizedString(@"Allows copying:", @"Info label"), SKInfoAllowsCopyingKey,
                            NSLocalizedString(@"Allows commenting:", @"Info label"), SKInfoAllowsCommentingKey,
                            NSLocalizedString(@"Title:", @"Info label"), PDFDocumentTitleAttribute,
                            NSLocalizedString(@"Author:", @"Info label"), PDFDocumentAuthorAttribute, 
                            NSLocalizedString(@"Subject:", @"Info label"), PDFDocumentSubjectAttribute, 
                            NSLocalizedString(@"Content Creator:", @"Info label"), PDFDocumentCreatorAttribute, 
                            NSLocalizedString(@"PDF Producer:", @"Info label"), PDFDocumentProducerAttribute, 
                            NSLocalizedString(@"Creation date:", @"Info label"), PDFDocumentCreationDateAttribute, 
                            NSLocalizedString(@"Modification date:", @"Info label"), PDFDocumentModificationDateAttribute, 
                            NSLocalizedString(@"Keywords:", @"Info label"), SKInfoKeywordsStringKey, nil];
    }
    return self;
}

- (void)updateForDocument:(NSDocument *)doc {
    [self setInfo:[self infoForDocument:doc]];
    [summaryTableView reloadData];
    [attributesTableView reloadData];
}

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:SKInfoWindowFrameAutosaveName];
    
    [summaryTableView setStyle:NSTableViewStylePlain];
    [attributesTableView setStyle:NSTableViewStylePlain];
    
    NSArray *tables = [NSArray arrayWithObjects:summaryTableView, attributesTableView, nil];
    NSTableView *tv;
    CGFloat width = 0.0;
    for (tv in tables) {
        NSTableColumn *tc = [tv tableColumnWithIdentifier:LABEL_COLUMN_ID];
        NSCell *cell = [tc dataCell];
        NSArray *keys = [tv isEqual:summaryTableView] ? summaryKeys : attributesKeys;
        NSUInteger row, rowMax = [tv numberOfRows];
        for (row = 0; row < rowMax; row++) {
            NSString *key = [keys objectAtIndex:row];
            if ([key length] == 0) continue;
            [cell setStringValue:[labels objectForKey:key] ?: [key stringByAppendingString:@":"]];
            width = fmax(width, ceil([cell cellSize].width));
        }
    }
    for (tv in tables) {
        NSTableColumn *tc = [tv tableColumnWithIdentifier:LABEL_COLUMN_ID];
        [tc setWidth:width];
        [tc setResizingMask:NSTableColumnNoResizing];
        [[tv tableColumnWithIdentifier:VALUE_COLUMN_ID] setResizingMask:NSTableColumnAutoresizingMask];
        [tv sizeToFit];
    }
    
    [self updateForDocument:[[[NSApp mainWindow] windowController] document]];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self selector: @selector(handleViewFrameDidChangeNotification:)
                                                 name: NSViewFrameDidChangeNotification object: [attributesTableView enclosingScrollView]];
    [nc addObserver: self selector: @selector(handleWindowDidBecomeMainNotification:)
                                                 name: NSWindowDidBecomeMainNotification object: nil];
    [nc addObserver: self selector: @selector(handleWindowDidResignMainNotification:)
                                                 name: NSWindowDidResignMainNotification object: nil];
    [nc addObserver: self selector: @selector(handlePDFDocumentInfoDidChangeNotification:)
                                                 name: PDFDocumentDidUnlockNotification object: nil];
    [nc addObserver: self selector: @selector(handlePDFDocumentInfoDidChangeNotification:)
                                                 name: SKPDFPageBoundsDidChangeNotification object: nil];
    [nc addObserver: self selector: @selector(handleDocumentFileURLDidChangeNotification:)
                                                 name: SKDocumentFileURLDidChangeNotification object: nil];
}

static NSString *SKFileSizeStringForFileURL(NSURL *fileURL, unsigned long long *physicalSizePtr, unsigned long long *logicalSizePtr) {
    if (fileURL == nil)
        return @"";
    
    unsigned long long size, logicalSize = 0;
    BOOL isDir = NO;
    NSMutableString *string = [NSMutableString string];
    NSDictionary *values = [fileURL resourceValuesForKeys:@[NSURLTotalFileSizeKey, NSURLTotalFileAllocatedSizeKey, NSURLIsDirectoryKey] error:NULL];
    
    logicalSize = [[values objectForKey:NSURLTotalFileSizeKey] unsignedLongLongValue];
    size = [[values objectForKey:NSURLTotalFileAllocatedSizeKey] unsignedLongLongValue];
    isDir = [[values objectForKey:NSURLIsDirectoryKey] boolValue];
    
    if (isDir) {
        NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtURL:fileURL includingPropertiesForKeys:@[NSURLTotalFileSizeKey, NSURLTotalFileAllocatedSizeKey] options:0 errorHandler:NULL];
        for (NSURL *subFileURL in dirEnum) {
            values = [subFileURL resourceValuesForKeys:@[NSURLTotalFileSizeKey, NSURLTotalFileAllocatedSizeKey, NSURLIsDirectoryKey] error:NULL];
            logicalSize += [[values objectForKey:NSURLTotalFileSizeKey] unsignedLongLongValue];
            size += [[values objectForKey:NSURLTotalFileAllocatedSizeKey] unsignedLongLongValue];
        }
    }
    
    if (physicalSizePtr)
        *physicalSizePtr = size;
    if (logicalSizePtr)
        *logicalSizePtr = logicalSize;
    
    if (size < 1000) {
        [string appendFormat:@"%qu %@", size, NSLocalizedString(@"bytes", @"size unit")];
    } else {
        #define numUnits 6
        NSString *units[numUnits] = {NSLocalizedString(@"kB", @"size unit"), NSLocalizedString(@"MB", @"size unit"), NSLocalizedString(@"GB", @"size unit"), NSLocalizedString(@"TB", @"size unit"), NSLocalizedString(@"PB", @"size unit"), NSLocalizedString(@"EB", @"size unit")};
        NSUInteger i;
        CGFloat sizef = size;
        for (i = 0; i < numUnits; i++, sizef /= 1000.0) {
            if ((sizef / 1000.0) < 1000.0 || i == numUnits - 1) {
                [string appendFormat:@"%.1f %@", sizef / 1000.0, units[i]];
                break;
            }
        }
    }
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [string appendFormat:@" (%@ %@)", [formatter stringFromNumber:[NSNumber numberWithUnsignedLongLong:logicalSize]], NSLocalizedString(@"bytes", @"size unit")];
    
    return string;
}

#define CM_PER_POINT 0.035277778
#define INCH_PER_POINT 0.013888889

static inline 
NSString *SKSizeString(NSSize size, NSSize altSize) {
    BOOL useMetric = [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue];
    NSString *units = useMetric ? NSLocalizedString(@"cm", @"size unit") : NSLocalizedString(@"in", @"size unit");
    CGFloat factor = useMetric ? CM_PER_POINT : INCH_PER_POINT;
    if (NSEqualSizes(size, altSize))
        return [NSString stringWithFormat:@"%.1f x %.1f %@", size.width * factor, size.height * factor, units];
    else
        return [NSString stringWithFormat:@"%.1f x %.1f %@  (%.1f x %.1f %@)", size.width * factor, size.height * factor, units, altSize.width * factor, altSize.height * factor, units];
}

- (NSDictionary *)infoForDocument:(NSDocument *)doc {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    PDFDocument *pdfDoc;
    unsigned long long logicalSize = 0, physicalSize = 0;
    
    if ([doc isPDFDocument] && (pdfDoc = [doc pdfDocument])) {
        [dictionary addEntriesFromDictionary:[pdfDoc documentAttributes]];
        [dictionary setValue:[NSString stringWithFormat: @"%ld.%ld", (long)[pdfDoc majorVersion], (long)[pdfDoc minorVersion]] forKey:SKInfoVersionKey];
        [dictionary setValue:[NSNumber numberWithInteger:[pdfDoc pageCount]] forKey:SKInfoPageCountKey];
        if ([pdfDoc pageCount]) {
            NSSize cropSize = [[pdfDoc pageAtIndex:0] boundsForBox:kPDFDisplayBoxCropBox].size;
            NSSize mediaSize = [[pdfDoc pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox].size;
            [dictionary setValue:SKSizeString(cropSize, mediaSize) forKey:SKInfoPageSizeKey];
            [dictionary setValue:[NSNumber numberWithDouble:cropSize.width] forKey:SKInfoPageWidthKey];
            [dictionary setValue:[NSNumber numberWithDouble:cropSize.height] forKey:SKInfoPageHeightKey];
        }
        [dictionary setValue:[[dictionary valueForKey:PDFDocumentKeywordsAttribute] componentsJoinedByString:@"\n"] forKey:SKInfoKeywordsStringKey];
        [dictionary setValue:[NSNumber numberWithBool:[pdfDoc isEncrypted]] forKey:SKInfoEncryptedKey];
        [dictionary setValue:[NSNumber numberWithBool:[pdfDoc allowsPrinting]] forKey:SKInfoAllowsPrintingKey];
        [dictionary setValue:[NSNumber numberWithBool:[pdfDoc allowsCopying]] forKey:SKInfoAllowsCopyingKey];
        [dictionary setValue:[NSNumber numberWithBool:[pdfDoc realAllowsCommenting]] forKey:SKInfoAllowsCommentingKey];
    }
    [dictionary setValue:[[[doc fileURL] path] lastPathComponent] forKey:SKInfoFileNameKey];
    [dictionary setValue:SKFileSizeStringForFileURL([doc fileURL], &physicalSize, &logicalSize) forKey:SKInfoFileSizeKey];
    [dictionary setValue:[NSNumber numberWithUnsignedLongLong:physicalSize] forKey:SKInfoPhysicalSizeKey];
    [dictionary setValue:[NSNumber numberWithUnsignedLongLong:logicalSize] forKey:SKInfoLogicalSizeKey];
    if ([doc respondsToSelector:@selector(tags)])
        [dictionary setValue:[(SKMainDocument *)doc tags] ?: @[] forKey:SKInfoTagsKey];
    if ([doc respondsToSelector:@selector(rating)])
        [dictionary setValue:[NSNumber numberWithDouble:[(SKMainDocument *)doc rating]] forKey:SKInfoRatingKey];
    
    return dictionary;
}

- (NSArray *)keys {
    return [attributesKeys arrayByAddingObjectsFromArray:summaryKeys];
}

- (void)handleViewFrameDidChangeNotification:(NSNotification *)notification {
    [attributesTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:[attributesKeys count] - 1]];
}

- (void)handleWindowDidBecomeMainNotification:(NSNotification *)notification {
    [self updateForDocument:[[[notification object] windowController] document]];
}

- (void)handleWindowDidResignMainNotification:(NSNotification *)notification {
    [self updateForDocument:nil];
}

- (void)handlePDFDocumentInfoDidChangeNotification:(NSNotification *)notification {
    NSDocument *doc = [[[NSApp mainWindow] windowController] document];
    if ([[doc pdfDocument] isEqual:[notification object]])
        [self updateForDocument:doc];
}

- (void)handleDocumentFileURLDidChangeNotification:(NSNotification *)notification {
    NSDocument *doc = [[[NSApp mainWindow] windowController] document];
    if ([doc isEqual:[notification object]])
        [self updateForDocument:doc];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    NSArray *keys = nil;
    if ([tv isEqual:summaryTableView])
        keys = summaryKeys;
    else if ([tv isEqual:attributesTableView])
        keys = attributesKeys;
    return [keys count];
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *view = [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
    static NSDateFormatter *shortDateFormatter = nil;
    if(shortDateFormatter == nil) {
        shortDateFormatter = [[NSDateFormatter alloc] init];
        [shortDateFormatter setDateStyle:NSDateFormatterShortStyle];
        [shortDateFormatter setTimeStyle:NSDateFormatterNoStyle];
    }
    NSArray *keys = nil;
    if ([tv isEqual:summaryTableView])
        keys = summaryKeys;
    else if ([tv isEqual:attributesTableView])
        keys = attributesKeys;
    NSString *key = [keys objectAtIndex:row];
    NSString *tcID = [tableColumn identifier];
    id value = nil;
    if ([key length]) {
        if ([tcID isEqualToString:LABEL_COLUMN_ID]) {
            value = [labels objectForKey:key] ?: [key stringByAppendingString:@":"];
        } else if ([tcID isEqualToString:VALUE_COLUMN_ID]) {
            value = [info objectForKey:key];
            if (value == nil)
                value = @"-";
            else if ([value isKindOfClass:[NSDate class]])
                value = [shortDateFormatter stringFromDate:value];
            else if ([value isKindOfClass:[NSNumber class]])
                value = ([key isEqualToString:SKInfoPageCountKey] ? [value stringValue] : ([value boolValue] ? NSLocalizedString(@"Yes", @"") : NSLocalizedString(@"No", @"")));
        }
    }
    [[view textField] setObjectValue:value];
    if ([tv isEqual:attributesTableView] && [[tableColumn identifier] isEqualToString:VALUE_COLUMN_ID])
        [[view textField] setLineBreakMode:row == [tv numberOfRows] - 1 ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail];
    return view;
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)row {
    CGFloat rowHeight = [tv rowHeight];
    if ([tv isEqual:attributesTableView] && row == [tv numberOfRows] - 1)
        rowHeight = fmax(rowHeight, NSHeight([[tv enclosingScrollView] bounds]) - [tv numberOfRows] * (rowHeight + [tv intercellSpacing].height) + rowHeight);
    return rowHeight;
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row {
    return NO;
}

@end
