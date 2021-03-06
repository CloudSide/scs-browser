//
//  S3Extensions.m
//  S3-Objc
//
//  Created by Bruce Chen on 3/31/06.
//  Modernized by Martin Hering on 07/14/12
//  Copyright 2014 Bruce Chen. All rights reserved.
//

#import "S3Extensions.h"
#import <CommonCrypto/CommonCrypto.h>

#define maxFilesNumberInDirectoryToUpload   2048

@implementation NSArray (Comfort)

- (NSArray *) expandPaths:(BOOL *)hasTooManyFiles
{
	NSMutableArray *a = [NSMutableArray array];
	BOOL dir;
	
	for(id pathOrURL in self)
	{
        NSString* path = ([pathOrURL isKindOfClass:[NSURL class]]) ? [pathOrURL path] : pathOrURL;
        
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir])
		{		
			if (!dir) {
                [a addObject:path];
                if ([a count] > maxFilesNumberInDirectoryToUpload) {
                    *hasTooManyFiles = YES;
                    return nil;
                }
            }
			else
			{
				NSString *file;
				NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
				
				while (file = [dirEnum nextObject]) 
				{
					if (![[file lastPathComponent] hasPrefix:@"."]) 
					{
						NSString* fullPath = [path stringByAppendingPathComponent:file];
						
						if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&dir])
							if (!dir) {
                                [a addObject:fullPath];
                                if ([a count] > maxFilesNumberInDirectoryToUpload) {
                                    *hasTooManyFiles = YES;
                                    return nil;
                                }
                            }
					}
				}
			}
		}
	}
	return a;
}

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (BOOL)hasObjectSatisfying:(SEL)aSelector withArgument:(id)argument;
{
    for(id object in self)
    {
        if ([object performSelector:aSelector withObject:argument]) {
            return YES;
        }
    }
    
    return NO;
}

@end

@implementation NSDictionary (URL)

- (NSString *)queryString
{
    if ([self count]==0)
        return @"";
    
    NSMutableString *s = [NSMutableString string];
    NSArray *keys = [self allKeys];
    NSString *k;
    NSInteger i;

    k = [keys objectAtIndex:0];
    [s appendString:@"?"];
    [s appendString:[k stringByEscapingHTTPReserved]];
    [s appendString:@"="];
    [s appendString:[[self objectForKey:k] stringByEscapingHTTPReserved]];
    
    for (i=1;i<[keys count];i++)
    {
        k = [keys objectAtIndex:i];
        [s appendString:@"&"];
        [s appendString:[k stringByEscapingHTTPReserved]];
        [s appendString:@"="];
        [s appendString:[[self objectForKey:k] stringByEscapingHTTPReserved]];
    }
    return s;
}

@end

@implementation NSMutableDictionary (Comfort)

- (void)safeSetObject:(id)o forKey:(NSString *)k
{
	if ((o==nil)||(k==nil))
		return;
	[self setObject:o forKey:k];
}

- (void)safeSetObject:(id)o forKey:(NSString *)k withValueForNil:(id)d
{
	if (k==nil)
		return;
	if (o!=nil)
		[self setObject:o forKey:k];
	else
		[self setObject:d forKey:k];
}

@end

@implementation NSXMLElement (Comfort)

- (NSXMLElement *)elementForName:(NSString *)n
{
	NSArray *a = [self elementsForName:n];
	if ([a count]>0)
		return [a objectAtIndex:0];
	else 
		return nil;
}

- (NSNumber *)longLongNumber
{
	return @([[self stringValue] longLongValue]);
}

- (NSNumber *)boolNumber
{
	// I don't trust the output format, the S3 doc sometimes mentions a "false;"
	if ([[self stringValue] rangeOfString:@"true" options:NSCaseInsensitiveSearch].location!=NSNotFound)
		return [NSNumber numberWithBool:TRUE];
	else
		return [NSNumber numberWithBool:FALSE];
}

- (NSDate *)dateValue
{
    return [[self stringValue] dateValue];
    /*
	id s = [[self stringValue] stringByAppendingString:@" +0000"];
	id d = [NSCalendarDate dateWithString:s calendarFormat:@"%Y-%m-%dT%H:%M:%S.%FZ %z"];
	return d;
     */
}

@end


@implementation NSData (CommonCryptoWrapper)

- (NSData *)md5Digest
{
    CFErrorRef error = NULL;
    
    SecTransformRef digestRef = SecDigestTransformCreate(kSecDigestMD5, 0, &error);
    SecTransformSetAttribute(digestRef, kSecTransformInputAttributeName, (__bridge CFDataRef)self, &error);
    CFDataRef resultData = SecTransformExecute(digestRef, &error);
    
    NSData* bridgedData = (__bridge_transfer NSData*)resultData;
    CFRelease(digestRef);
    
    return bridgedData;
}

- (NSData *)sha1Digest
{
    CFErrorRef error = NULL;
    
    SecTransformRef digestRef = SecDigestTransformCreate(kSecDigestSHA1, 0, &error);
    SecTransformSetAttribute(digestRef, kSecTransformInputAttributeName, (__bridge CFDataRef)self, &error);
    CFDataRef resultData = SecTransformExecute(digestRef, &error);
    
    NSData* bridgedData = (__bridge_transfer NSData*)resultData;
    CFRelease(digestRef);
    
    return bridgedData;
}

- (NSData *)sha1HMacWithKey:(NSString *)key
{
	CFErrorRef error = NULL;
    
    NSData* keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    SecTransformRef digestRef = SecDigestTransformCreate(kSecDigestHMACSHA1, 0, &error);
    SecTransformSetAttribute(digestRef, kSecDigestHMACKeyAttribute, (__bridge CFDataRef)keyData, &error);
    SecTransformSetAttribute(digestRef, kSecTransformInputAttributeName, (__bridge CFDataRef)self, &error);
    
    CFDataRef resultData = SecTransformExecute(digestRef, &error);
    
    NSData* bridgedData = (__bridge_transfer NSData*)resultData;
    CFRelease(digestRef);
    
    return bridgedData;
}
	
- (NSString *)encodeBase64
{
    return [self encodeBase64WithNewlines:NO];
}

- (NSString *) encodeBase64WithNewlines:(BOOL) encodeWithNewlines
{
    CFErrorRef error = NULL;
    
    SecTransformRef encodingRef = SecEncodeTransformCreate(kSecBase64Encoding, &error);
    SecTransformSetAttribute(encodingRef, kSecTransformInputAttributeName, (__bridge CFDataRef)self, &error);
    CFDataRef resultData = SecTransformExecute(encodingRef, &error);
    
    NSString *base64String = [[NSString alloc] initWithData:(__bridge NSData*)resultData encoding:NSASCIIStringEncoding];
    
    CFRelease(encodingRef);
    CFRelease(resultData);

    return base64String;
}
@end

@implementation NSString (CommonCryptoWrapper)

- (NSData *)decodeBase64;
{
    return [self decodeBase64WithNewlines:YES];
}

- (NSData *)decodeBase64WithNewlines:(BOOL)encodedWithNewlines;
{
    CFErrorRef error = NULL;
    
    NSData* inputData = [self dataUsingEncoding:NSUTF8StringEncoding];
    
    SecTransformRef decodingRef = SecDecodeTransformCreate(kSecBase64Encoding, &error);
    SecTransformSetAttribute(decodingRef, kSecTransformInputAttributeName, (__bridge CFDataRef)inputData, &error);
    CFDataRef resultData = SecTransformExecute(decodingRef, &error);
    
    NSData* bridgedData = (__bridge_transfer NSData*)resultData;
    CFRelease(decodingRef);

    return bridgedData;
}

- (NSNumber *)fileSizeForPath
{
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self error:nil];;
	if (fileAttributes==nil)
		return @0LL;
    else
        return [fileAttributes objectForKey:NSFileSize];
}

- (NSString *)readableSizeForPath
{
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self error:nil];
	if (fileAttributes==nil)
		return @"Unknown";
	
    return [[fileAttributes objectForKey:NSFileSize] readableFileSize];
}

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (NSString *)mimeTypeForPath
{
	FSRef fsRef;
	CFStringRef utiType;
	OSStatus err;
	
	// Fast path for some mime types not correctly handling through UTI
	if ([[self pathExtension] isEqualToString:@"css"])
		return @"text/css";
	if ([[self pathExtension] isEqualToString:@"dmg"])
		return @"application/x-apple-diskimage";
			
	err= FSPathMakeRef((const UInt8 *)[self fileSystemRepresentation], &fsRef, NULL);
	if(err != noErr)
		return nil;
	LSCopyItemAttribute(&fsRef,kLSRolesAll,kLSItemContentType, (CFTypeRef*)&utiType);
	if(err != noErr)
		return nil;
	CFStringRef mimeType = UTTypeCopyPreferredTagWithClass(utiType, kUTTagClassMIMEType);
	return (NSString *)CFBridgingRelease(mimeType);
}

+ (NSString *)readableSizeForPaths:(NSArray *)files
{
	NSString *path;
	unsigned long long total = 0;
	
	for (path in files)
	{
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		if (fileAttributes!=nil)
			total = total + [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];				
	}
	
    return [NSString readableFileSizeFor:total];
}

+ (NSString *)readableFileSizeFor:(unsigned long long) size
{
    NSArray *filesizename = [NSArray arrayWithObjects:@" Bytes", @" KB", @" MB", @" GB", @" TB", @" PB", @" EB", @" ZB", @" YB", nil];
	
	if (size > 0) {
		
		int i = floor(log2(size) / 10);
        if (i > 8) i = 8;
		double s = size / pow(1024, i);
        
		return [NSString stringWithFormat:@"%.2f%@", s, [filesizename objectAtIndex:i]];
	}
	
	return @"0 Bytes";
}

+ (NSString *)commonPathComponentInPaths:(NSArray *)paths
{
	NSString *prefix = [NSString commonPrefixWithStrings:paths]; 
	NSRange r = [prefix rangeOfString:@"/" options:NSBackwardsSearch];
	if (r.location!=NSNotFound)
		return [prefix substringToIndex:(r.location+1)];
	else
		return @"";
}

+ (NSString *)commonPrefixWithStrings:(NSArray *)strings
{
	NSUInteger sLength = [strings count];
	int i,j;
	
	if (sLength == 1)
		return [strings objectAtIndex:0];
	else 
	{
		NSString* prefix = [strings objectAtIndex:0];
		NSUInteger maxLength = [prefix length];
		
		for (i = 1; i < sLength; i++)
			if ([[strings objectAtIndex:i] length] < maxLength)
				maxLength = [[strings objectAtIndex:i] length];
		
		for (i = 0; i < maxLength; i++) {
			unichar c = [prefix characterAtIndex:i];
			
			for (j = 1; j < sLength; j++) {
				NSString* compareString = [strings objectAtIndex:j];
				
				if ([compareString characterAtIndex:i] != c) {
					if (i == 0) {
						return @"";
					} else {
						return [prefix substringToIndex:i];
                    }
                }
			}
		}
		
		return [prefix substringToIndex:maxLength];
	}
}

@end


@implementation NSNumber (Comfort)

- (NSString *)readableFileSize
{
	return [NSString readableFileSizeFor:[self unsignedLongLongValue]];
}

@end

@implementation NSString (URL)

- (NSString *)stringByEscapingHTTPReserved
{
	// Escape all Reserved characters from rfc 2396 section 2.2
	// except "/" since that's used explicitly in format strings.
	CFStringRef escapeChars = (CFStringRef)@";?:@&=+$,";
	return (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
			(CFStringRef)self, NULL, escapeChars, kCFStringEncodingUTF8));
}

@end



@implementation NSString (Date)

- (NSDate *)dateValue {
    
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    static NSString *dateFormatterKey = @"S3DateFormatter";
    
    NSDateFormatter *dateFormatter = [dictionary objectForKey:dateFormatterKey];
    
    if (dateFormatter == nil) {
        
        dateFormatter = [NSDateFormatter new];
        // Must set locale to ensure consistent parsing:
        // http://developer.apple.com/iphone/library/qa/qa2010/qa1480.html
        
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
        [dictionary setObject:dateFormatter forKey:dateFormatterKey];
    }
    
    return [dateFormatter dateFromString:self];
}

@end

@implementation NSString (FormatJSON)

- (NSData *)formatJsonFor:(NSString *)string
{
    if (string == nil) {
        return nil;
    }
    
    int indentLevel = 0;
    BOOL inString    = NO;
    char currentChar = '\0';
    char *tab = "    ";
    
    NSUInteger len = [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    const char *utf8 = [self UTF8String];
    NSMutableData *buf = [NSMutableData dataWithCapacity:(NSUInteger)(len * 1.1f)];
    
    for (int i = 0; i < len; i++)
    {
        currentChar = utf8[i];
        
        switch (currentChar) {
            case '{':
            case '[':
                if (!inString) {
                    [buf appendBytes:&currentChar length:1];
                    [buf appendBytes:"\n" length:1];
                    
                    for (int j = 0; j < indentLevel+1; j++) {
                        [buf appendBytes:tab length:strlen(tab)];
                    }
                    
                    indentLevel += 1;
                } else {
                    [buf appendBytes:&currentChar length:1];
                }
                break;
            case '}':
            case ']':
                if (!inString) {
                    indentLevel -= 1;
                    [buf appendBytes:"\n" length:1];
                    for (int j = 0; j < indentLevel; j++) {
                        [buf appendBytes:tab length:strlen(tab)];
                    }
                    [buf appendBytes:&currentChar length:1];
                } else {
                    [buf appendBytes:&currentChar length:1];
                }
                break;
            case ',':
                if (!inString) {
                    [buf appendBytes:",\n" length:2];
                    for (int j = 0; j < indentLevel; j++) {
                        [buf appendBytes:tab length:strlen(tab)];
                    }
                } else {
                    [buf appendBytes:&currentChar length:1];
                }
                break;
            case ':':
                if (!inString) {
                    [buf appendBytes:":" length:1];
                } else {
                    [buf appendBytes:&currentChar length:1];
                }
                break;
            case ' ':
            case '\n':
            case '\t':
                if (inString) {
                    [buf appendBytes:&currentChar length:1];
                }
                break;
            case '"':
                
                if (i > 0 && utf8[i-1] != '\\')
                {
                    inString = !inString;
                }
                
                [buf appendBytes:&currentChar length:1];
                break;
            default:
                [buf appendBytes:&currentChar length:1];
                break;
        }
    }
    
    //return [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
    return buf;
}

@end


@implementation NSData (ResponseDataFormatter)

- (id)jsonString {
    
    NSError *jsonParseError = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:self options:kNilOptions error:&jsonParseError];
    
    if (jsonParseError == nil && jsonObject && [jsonObject isKindOfClass:[NSDictionary class]]) {
        return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
    }else {
        return self;
    }
}

- (id)formatteredJson {
    
    
    if ([self jsonString] && [[self jsonString] isKindOfClass:[NSString class]]) {
        
        NSString * string = [self jsonString];
        return [string formatJsonFor:string];
        
    }else {
        
        return self;
    }
}

@end