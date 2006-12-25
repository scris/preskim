//
//  BDSKSearchGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKSearchGroup.h"
#import "NSImage+Toolbox.h"

// max number of results from NCBI is 100, except on evenings and weekends
#define MAX_RESULTS 50

/* Based on public domain sample code written by Oleg Khovayko, available at
 http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_example.pl
 
 - We limit requests to 100 in the editor interface, per NCBI's request.  
 - We also pass tool=bibdesk for their tracking purposes.  
 - We use lower case characters in the URL /except/ for WebEnv
 - See http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html for details.
 
 */

@implementation BDSKSearchGroup

+ (NSString *)baseURLString { return @"http://eutils.ncbi.nlm.nih.gov/entrez/eutils"; }

// may be useful for UI validation
+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:[self baseURLString]];
    CFNetDiagnosticRef diagnostic = CFNetDiagnosticCreateWithURL(CFGetAllocator(theURL), theURL);
    
    NSString *details;
    CFNetDiagnosticStatus status = CFNetDiagnosticCopyNetworkStatusPassively(diagnostic, (CFStringRef *)&details);
    CFRelease(diagnostic);
    [details autorelease];
    
    BOOL canConnect = kCFNetDiagnosticConnectionUp == status;
    if (NO == canConnect)
        NSLog(@"%@", details);
    
    return canConnect;
}

- (id)initWithName:(NSString *)aName;
{
    // this URL is basically just to prevent an assertion failure in the superclass
    self = [super initWithName:aName URL:[NSURL URLWithString:[[self class] baseURLString]]];
    if (self) {
    }
    return self;
}

- (void)dealloc
{
    [webEnv release];
    [queryKey release];
    [searchTerm release];
    [searchKey release];
    [super dealloc];
}

// note that pointer equality is used for these groups, so names can overlap, and users can have duplicate searches

- (NSImage *)icon {
    return [NSImage smallImageNamed:@"searchFolderIcon"];
}

- (BOOL)isSearch { return YES; }
- (void)setWebEnv:(NSString *)env;
{
    [webEnv autorelease];
    webEnv = [env copy];
}

- (void)setQueryKey:(NSString *)aKey;
{
    [queryKey autorelease];
    queryKey = [aKey copy];
}

// super's implementation does some things that we don't want (undo, setPublications:nil, setName:)
- (void)setURL:(NSURL *)newURL;
{
    if (URL != newURL) {
        [URL release];
        URL = [newURL copy];
    }
}

- (NSString *)queryKey { return queryKey; }

- (NSString *)webEnv { return webEnv; }

- (BOOL)isURL { return NO; }

- (BOOL)isEditable { return NO; }

- (void)resetSearch;
{
    // get the initial XML document with our search parameters in it
    NSString *esearch = [[[self class] baseURLString] stringByAppendingFormat:@"/esearch.fcgi?db=pubmed&retmax=1&usehistory=y&term=%@&tool=bibdesk", [self searchTerm]];
    NSURL *initialURL = [NSURL URLWithString:esearch]; 
    NSAssert(initialURL, @"unable to create initial query URL");
    
    NSURLRequest *request = [NSURLRequest requestWithURL:initialURL];
    NSURLResponse *response;
    NSError *error;
    NSData *esearchResult = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSXMLDocument *document = nil;
    if (nil == esearchResult)
        NSLog(@"failed to download %@ with error %@", initialURL, error);
    else
        document = [[NSXMLDocument alloc] initWithData:esearchResult options:NSXMLNodeOptionsNone error:&error];
    
    if (nil != document) {
        NSXMLElement *root = [document rootElement];
        
        // we need to extract WebEnv, Count, and QueryKey to construct our final URL
        [self setWebEnv:[[[root nodesForXPath:@"/eSearchResult[1]/WebEnv[1]" error:NULL] lastObject] stringValue]];
        [self setQueryKey:[[[root nodesForXPath:@"/eSearchResult[1]/QueryKey[1]" error:NULL] lastObject] stringValue]];
        NSString *countString = [[[root nodesForXPath:@"/eSearchResult[1]/Count[1]" error:NULL] lastObject] stringValue];
        availableResults = countString ? [countString intValue] : 0;
        
        [document release];
        
    } else if (nil != esearchResult) {
        // make sure error was actually initialized by NSXMLDocument
        NSLog(@"unable to create an XML document: %@", error);
    }
}

- (void)fetch;
{
    if ([self webEnv] == nil || [self queryKey] == nil || availableResults <= fetchedResults)
        return;
    
    int numResults = MIN(availableResults - fetchedResults, MAX_RESULTS);
    NSString *efetch = [[[self class] baseURLString] stringByAppendingFormat:@"/efetch.fcgi?rettype=medline&retmode=text&retstart=%d&retmax=%d&db=pubmed&query_key=%@&WebEnv=%@&tool=bibdesk", fetchedResults, numResults, [self queryKey], [self webEnv]];
    NSURL *theURL = [NSURL URLWithString:efetch];
    NSAssert(theURL, @"unable to create fetch URL");

    fetchedResults += numResults;
    
    [self setURL:theURL];
    [self startDownload];
    
    // use this to notify the tableview to start the progress indicators and disable the button
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
}

- (void)search;
{
    if ([self isRetrieving])
        return;
    
    [self setWebEnv:nil];
    [self setQueryKey:nil];

    fetchedResults = 0;
    availableResults = 0;
    
    
    if ([NSString isEmptyString:[self searchTerm]]) {
        [self setURL:nil];
        [self setPublications:[NSArray array]];
    } else {
        [self setPublications:nil];
        [self resetSearch];
        [self fetch];
    }
}

- (void)searchNext;
{
    if ([self isRetrieving])
        return;
    
    if ([NSString isEmptyString:[self searchTerm]]) {
        [self setURL:nil];
    } else {
        if ([self searchKey] == nil || [self webEnv] == nil)
            [self resetSearch];
        [self fetch];
    }
}

- (void)setSearchTerm:(NSString *)aTerm;
{
    if ([aTerm isEqualToString:searchTerm] == NO) {
        [searchTerm autorelease];
        searchTerm = [aTerm copy];
        
        [self search];
    }
}

- (NSString *)searchTerm { return searchTerm; }

// searchKey is currently unused
- (void)setSearchKey:(NSString *)aKey;
{
    if ([aKey isEqualToString:searchKey] == NO) {
        [searchKey autorelease];
        searchKey = [aKey copy];
        
        [self setWebEnv:nil];
        [self setQueryKey:nil];

        fetchedResults = 0;
        
        [self search];
    }
}

- (NSString *)searchKey { return searchKey; }

// this returns nil if no searchTerm has been set, to avoid an error message
- (id)publications {
    return [NSString isEmptyString:[self searchTerm]] ? nil : [super publications];
}

- (BOOL)hasMoreResults;
{
    return availableResults > fetchedResults;
}

@end
