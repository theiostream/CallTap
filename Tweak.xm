#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import "ClickToCall.h"

// NOTE: The CT prefix is not related to CoreTelephony whatsoever.
// NOTE: I felt like I should add some note on this project.
// NOTE: Yay yet another note!

/*%%
TODO:
2. Maybe *all* ABPropertyIDs chooseable
	(are all of them selectable?)
%%*/

/*
-- 0: nothing
-- 1: call
-- 2: message
-- 3: mail
-- 4: facetime
-- 5: detail
*/

#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif
#define isiOS6() (kCFCoreFoundationVersionNumber>=kCFCoreFoundationVersionNumber_iOS_6_0)

#define LAME_IS_IPHONE ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:"]])
extern "C" char *CPPhoneNumberCopyNormalized(char *);

/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Preferences
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

static NSDictionary *contactsPrefs = nil;

static void CTContactsUpdatePrefs() {
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/am.theiostre.clicktocall.plist"];
	if (!plist) return;

	contactsPrefs = [plist retain];
}

static void CTContactsReloadPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	CTContactsUpdatePrefs();
}

static NSInteger CTGetIntPref(NSString *key, int def) {
	if (!contactsPrefs) return def;

	NSNumber *v = [contactsPrefs objectForKey:key];
	return v ? [v intValue] : def;
}

/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

static ABMultiValueRef CTPropertyValue(ABRecordRef person, ABPropertyID property) {
	ABMultiValueRef valueRef = ABRecordCopyValue(person, property);
	if (!valueRef)
		return NULL;
	
	if (ABMultiValueGetCount(valueRef) <= 0) {
		CFRelease(valueRef);
		return NULL;
	}
	
	return valueRef;
}

@interface CTGestureHandler : NSObject <UIActionSheetDelegate> {
	NSString *_scheme;
}

+ (id)sharedInstance;
- (BOOL)hasGesture:(NSString *)spec defaultValue:(int)def person:(ABRecordRef)person;
- (CFArrayRef)resultForGesture:(int)gesture person:(ABRecordRef)person createScheme:(BOOL)doScheme scheme:(NSString **)scheme title:(NSString **)title;
- (void)runActionWithGesture:(NSString *)spec defaultValue:(int)def person:(ABRecordRef)person isNothing:(BOOL *)nothing willExpand:(BOOL *)expand actionSheetView:(UIView *)view;
@end

static CTGestureHandler *sharedInstance_ = nil;
@implementation CTGestureHandler
+ (id)sharedInstance {
	if (!sharedInstance_)
		sharedInstance_ = [[CTGestureHandler alloc] init];
	
	return sharedInstance_;
}

- (BOOL)hasGesture:(NSString *)spec defaultValue:(int)def person:(ABRecordRef)person {
	int gesture = CTGetIntPref(spec, def);
	if (gesture == 0) return NO;
	if (gesture == 5) return YES;
	
	CFArrayRef res = [self resultForGesture:gesture person:person createScheme:NO scheme:NULL title:NULL];
	
	if (!res || CFArrayGetCount(res) == 0) {
		CFRelease(res);
		return NO;
	}
	
	CFRelease(res);
	return YES;
}

- (void)runActionWithGesture:(NSString *)spec defaultValue:(int)def person:(ABRecordRef)person isNothing:(BOOL *)nothing willExpand:(BOOL *)expand actionSheetView:(UIView *)view {
	int gesture = CTGetIntPref(spec, def);
	
	*nothing = gesture==0;
	*expand = gesture==5;
	
	if (gesture == 0 || gesture == 5)
		return;
	
	NSString *scheme, *title;
	CFArrayRef result = [self resultForGesture:gesture person:person createScheme:YES scheme:&scheme title:&title];
	
	UIActionSheet *actionSheet = [[[UIActionSheet alloc] init] autorelease];
	[actionSheet setDelegate:self];
	[actionSheet setTitle:title];
	
	int i, count=CFArrayGetCount(result);
	for (i=0; i<count; i++) {
		ABMultiValueRef multiValue = CFArrayGetValueAtIndex(result, i);
		
		int j, jcount=ABMultiValueGetCount(multiValue);
		
		for (j=0; j<jcount; j++) {
			CFStringRef label_ = ABMultiValueCopyLabelAtIndex(multiValue, j);
			CFStringRef label = ABAddressBookCopyLocalizedLabel(label_);
			CFStringRef phone = (CFStringRef)ABMultiValueCopyValueAtIndex(multiValue, j);
			
			[actionSheet _addButtonWithTitle:(NSString *)phone label:(NSString *)label];
			
			CFRelease(label_);
			CFRelease(label);
			CFRelease(phone);
		}
	}
	
	CFRelease(result);
	
	NSInteger index = [actionSheet addButtonWithTitle:@"Cancel"];
	NSLog(@"apparently the new button index is %ld", (long)index);
	[actionSheet setCancelButtonIndex:index];
	
	_scheme = scheme;
	[actionSheet showInView:view];
}

- (CFArrayRef)resultForGesture:(int)gesture person:(ABRecordRef)person createScheme:(BOOL)doScheme scheme:(NSString **)scheme title:(NSString **)title {
	CFMutableArrayRef result = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
	NSMutableArray *props = [NSMutableArray array];
	
	NSNumber *phone, *email;
	switch (gesture) {
		case 1:
			if (doScheme) {
				*scheme = @"tel:";
				*title = @"Call";
			}
			
			phone = [NSNumber numberWithInt:kABPersonPhoneProperty];
			[props addObject:phone];
			
			break;
		
		case 2:
			if (doScheme) {
				*scheme = @"sms:";
				*title = @"Message";
			}
			
			phone = [NSNumber numberWithInt:kABPersonPhoneProperty];
			email = [NSNumber numberWithInt:kABPersonEmailProperty];
			
			[props addObject:phone];
			[props addObject:email];
			
			break;
		
		case 3:
			if (doScheme) {
				*scheme = @"mailto:";
				*title = @"Mail";
			}
			
			email = [NSNumber numberWithInt:kABPersonEmailProperty];
			[props addObject:email];
			
			break;
			
		case 4:
			if (doScheme) {
				*scheme = @"facetime:";
				*title = @"FaceTime";
			}
			
			phone = [NSNumber numberWithInt:kABPersonPhoneProperty];
			email = [NSNumber numberWithInt:kABPersonEmailProperty];
			
			[props addObject:phone];
			[props addObject:email];
			
			break;
		
		default:
			return NULL;
	}
	
	for (NSNumber *number in props) {
		ABPropertyID propertyID = [number intValue];
		ABMultiValueRef stuff = CTPropertyValue(person, propertyID);
		if (!stuff)
			continue;
		
		CFArrayAppendValue(result, stuff);
		CFRelease(stuff);
	}
	
	return result;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSString *target, *targetURL;
	char *justInCasePhoneNumber;
	
	NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
	if ([title isEqualToString:@"Cancel"]) {
		[actionSheet dismissWithClickedButtonIndex:buttonIndex animated:YES];
		return;
	}
	
	// I hope no invalid phone number will be inserted in the phone field.
	int i, len=[title length];
	for (i=0; i<len; i++) {
		char c = [title characterAtIndex:i];
		if (!isdigit(c) && c!='+' && c!='-' && c!=' ' && c!='(' && c!=')') {
			target = title;
			goto handle;
		}
	}
	
	justInCasePhoneNumber = CPPhoneNumberCopyNormalized((char *)[title UTF8String]);
	target = [NSString stringWithCString:justInCasePhoneNumber encoding:NSUTF8StringEncoding];
	free(justInCasePhoneNumber);
	
	handle:
	targetURL = [NSString stringWithFormat:@"%@%@", _scheme, target];
	NSLog(@"Clicked action sheet and made target URL %@", targetURL);
	
	[_scheme release];
	
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:targetURL]];
	
	[actionSheet dismissWithClickedButtonIndex:buttonIndex animated:YES];
}
@end

/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Hooks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

%hook ABMembersDataSource
%new
- (ABRecordRef)recordWithGlobalIndex:(NSInteger)globalIndex {
	ABModel *model = [self model];
	ABRecordRef person = [model displayedMemberAtIndex:globalIndex];
	
	return person;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = %orig;
	NSInteger idx = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
	
	if (LAME_IS_IPHONE && [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"] && isiOS6()) {
		if (idx == 0) return cell;
		idx--;
	}
	
	ABRecordRef per = [self recordWithGlobalIndex:idx];
	
	if ([[CTGestureHandler sharedInstance] hasGesture:@"CTLongPressGesture" defaultValue:2 person:per]) {
		lp_ges:
		UILongPressGestureRecognizer *longPress = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)] autorelease];
		[cell addGestureRecognizer:longPress];
	}
	else if (CTGetIntPref(@"CTShow", 0))
		goto lp_ges;
	
	if ([[CTGestureHandler sharedInstance] hasGesture:@"CTAccessoryViewGesture" defaultValue:5 person:per]) {
		av_ges:
		[cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
	}
	else if (CTGetIntPref(@"CTShow", 0))
		goto av_ges;
	
	NSLog(@"bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSInteger idx = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
	if (LAME_IS_IPHONE && [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"] && isiOS6()) idx--;
	
	BOOL nothing, expand;
	
	CTGestureHandler *handler = [CTGestureHandler sharedInstance];
	[handler runActionWithGesture:@"CTTapGesture" defaultValue:1 person:[self recordWithGlobalIndex:idx] isNothing:&nothing willExpand:&expand actionSheetView:tableView];
	if (!nothing) {
		if (!expand) {
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
			return;
		}
	}
	
	%orig;
}

%new(v@:@@)
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	NSInteger idx = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
	if (LAME_IS_IPHONE && [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"] && isiOS6()) idx--;
	
	BOOL nothing, expand;
	
	ABRecordRef record = [self recordWithGlobalIndex:idx];
	CTGestureHandler *handler = [CTGestureHandler sharedInstance];
	[handler runActionWithGesture:@"CTAccessoryViewGesture" defaultValue:5 person:record isNothing:&nothing willExpand:&expand actionSheetView:tableView];
	
	if (nothing)
		return;
	
	if (expand) {
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		[(ABMembersController *)[self delegate] abDataSource:self selectedPerson:record atIndexPath:indexPath withMemberCell:cell animate:YES];
	}
}

%new(v@:@)
- (void)didLongPress:(UILongPressGestureRecognizer *)recognizer {
	if ([recognizer state] == UIGestureRecognizerStateBegan) {
		ABMemberCell *cell = (ABMemberCell *)[recognizer view];
		UITableView *tableView = (UITableView *)cell;
		while (1) {
			tableView = (UITableView *)[tableView superview];
			if ([tableView isKindOfClass:[UITableView class]]) break;
		}
		
		NSIndexPath *cellIndexPath = [tableView indexPathForCell:cell];
		NSInteger idx = [[tableView _rowData] globalRowForRowAtIndexPath:cellIndexPath];
		if (LAME_IS_IPHONE && [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"] && isiOS6()) idx--;
		
		BOOL nothing, expand;
		
		ABRecordRef record = [self recordWithGlobalIndex:idx];
		CTGestureHandler *handler = [CTGestureHandler sharedInstance];
		[handler runActionWithGesture:@"CTLongPressGesture" defaultValue:2 person:record isNothing:&nothing willExpand:&expand actionSheetView:tableView];
		
		if (nothing)
			return;
		
		if (expand)
			[[self delegate] abDataSource:self selectedPerson:record atIndexPath:cellIndexPath withMemberCell:cell animate:YES];
	}
}
%end

%ctor {
	NSAutoreleasePool *p = [NSAutoreleasePool new];
	%init;

	CTContactsUpdatePrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
									NULL,
									&CTContactsReloadPrefs,
									CFSTR("am.theiostre.clicktocall.reload"),
									NULL,
									0);
	
	[p drain];
}
