//
//  GPSmanager.m
//  Timesheets
//
//  Created by Paul Kirvan on 19/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GPSmanager.h"
#import "Timesheets-Swift.h"

@implementation GPSmanager

@synthesize delegate, RecordToUpdate;

- (id) init
{
    self = super.init;
    
    if (self) 
    {        
        LocationFinder = CLLocationManager.alloc.init;
        LocationFinder.delegate = self;
        LocationFinder.desiredAccuracy = kCLLocationAccuracyBest;
        Mode = NearestGC;           
        NSString *myfile = [NSBundle.mainBundle pathForResource:@"GlidingCentreCoordinates" ofType:@"plist"];
        UnitList = [NSDictionary.alloc initWithContentsOfFile:myfile];
        [self InitializeAerodromeList];
    }
    
    return self;
}

- (void) InitializeAerodromeList
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString* region = [defaults stringForKey:@"Region"];
    NSString* fileName = [NSString stringWithFormat:@"%@Aerodromes",region];
    
    NSString* myfile = [NSBundle.mainBundle pathForResource:fileName ofType:@"csv"];
    NSString* RawList = [NSString.alloc initWithContentsOfFile:myfile encoding:NSASCIIStringEncoding error:NULL];
    NSMutableCharacterSet* Separators = NSMutableCharacterSet.newlineCharacterSet;
    [Separators addCharactersInString:@","];
    NSArray* Components = [RawList componentsSeparatedByCharactersInSet:Separators];
    NSMutableDictionary* NewAerodromeList = NSMutableDictionary.alloc.init;
    NSString* Ident;
    
    for (int i = 0; i < Components.count; i += 3) 
    {
        Ident = Components[i];
        NSMutableDictionary* NewEntry = NSMutableDictionary.alloc.init;
        NewEntry[@"Latitude"] = Components[i+1];
        NewEntry[@"Longitude"] = Components[i+2];
        NewAerodromeList[Ident] = NewEntry;
    }
    
    AerodromeList = [NSDictionary.alloc initWithDictionary:NewAerodromeList];
    
}


- (void) UpdateGlidingCentre
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString* defaultsRegion = [defaults stringForKey:@"Region"];

    if (defaultsRegion == nil)
    {
        [defaults setObject:@"Prairie" forKey:@"Region"];
        [defaults synchronize];
        
        BOOL iPad = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ? YES : NO;
        NSString* errorText;
        
        if (iPad)
        {
            errorText = @"Your region has been set to Prairie by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left.";
        }
        
        else
        {
            errorText = @"Your region has been set to Prairie by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left of the pilots tab.";
        }
        
        UIAlertController* regionAlert = [UIAlertController alertControllerWithTitle:@"Region Set" message:errorText preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* OKbutton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [regionAlert addAction:OKbutton];
        
        UIViewController *rootController = (UIViewController *)((TimesheetsAppDelegate *)UIApplication.sharedApplication.delegate).window.rootViewController;
        
        if (rootController.presentedViewController)
        {
            [rootController.presentedViewController presentViewController:regionAlert animated:YES completion:nil];
        }
        
        else
        {
            [rootController presentViewController:regionAlert animated:YES completion:nil];
        }
        
        [self.delegate reloadFetchedResults:nil];
        
        [delegate updateGlidingCentreButton:@"Gimli"];
    }

    Mode = NearestGC;
    [LocationFinder stopUpdatingLocation];
    [LocationFinder startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if ((status == kCLAuthorizationStatusDenied) || (status == kCLAuthorizationStatusRestricted))
    {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString* defaultsRegion = [defaults stringForKey:@"Region"];
        
        if (defaultsRegion == nil) 
        {
            [defaults setObject:@"Prairie" forKey:@"Region"];
            [defaults synchronize];
            
            BOOL iPad = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ? YES : NO;
            NSString* errorText;
            
            if (iPad) 
            {
                errorText = @"Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left.";
            }
            
            else 
            {
                errorText = @"Your region has been set to Northwest by default. This can be changed in settings. You will have to chose your gliding centre manually at the top left of the pilots tab.";
            }
            UIAlertController* regionAlert = [UIAlertController alertControllerWithTitle:@"Region Set" message:errorText preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* OKbutton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [regionAlert addAction:OKbutton];
            
            UIViewController *rootController = (UIViewController *)((TimesheetsAppDelegate *)UIApplication.sharedApplication.delegate).window.rootViewController;
            
            if (rootController.presentedViewController)
            {
                [rootController.presentedViewController presentViewController:regionAlert animated:YES completion:nil];
            }
            
            else
            {
                [rootController presentViewController:regionAlert animated:YES completion:nil];
            }
            
            [self.delegate reloadFetchedResults:nil];
        }
    }
}

- (void) AddXcountryStart:(FlightRecord*) Record
{
    startOfMeasurement = NSDate.date;
    self.RecordToUpdate = Record;
    Mode = XcountryStart;
    [LocationFinder stopUpdatingLocation];
    [LocationFinder startUpdatingLocation];
    timeToEndLocationUpdates = [NSTimer scheduledTimerWithTimeInterval:60 target:LocationFinder selector:@selector(stopUpdatingLocation) userInfo:nil repeats:NO];
}

- (void) AddXcountryEnd:(FlightRecord*) Record
{
    startOfMeasurement = NSDate.date;
    self.RecordToUpdate = Record;
    Mode = XcountryEnd;
    [LocationFinder stopUpdatingLocation];
    [LocationFinder startUpdatingLocation];
    timeToEndLocationUpdates = [NSTimer scheduledTimerWithTimeInterval:60 target:LocationFinder selector:@selector(stopUpdatingLocation) userInfo:nil repeats:NO];
}

# pragma mark -
# pragma mark Location Manager Delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{    
    if ((newLocation.horizontalAccuracy > 500) || (newLocation.timestamp.timeIntervalSinceNow < -60))
    {
        return;
    }
    
    NSMutableDictionary* List = UnitList.mutableCopy;
    BOOL regionIsUnknown = YES;
    BOOL RGSunderway = NSDate.date.IsDuringSummerOps;
    
    if (Mode == NearestGC) 
    {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString* region = [defaults stringForKey:@"Region"];
        if (region) 
        {
            regionIsUnknown = NO;
            NSMutableArray* wrongRegionSites = NSMutableArray.array;
            for (NSString* siteName in List) 
            {
                NSDictionary* site = List[siteName];
                if (![site[@"Region"] isEqualToString:region]) 
                {
                    [wrongRegionSites addObject:siteName];
                }
                
                else 
                {
                    if (site[@"SummerUnit"] != nil) 
                    {
                        BOOL summerUnitBool = [site[@"SummerUnit"] boolValue];
                        
                        if (summerUnitBool != RGSunderway) 
                        {
                            [wrongRegionSites addObject:siteName];
                        }
                    }
                }
            }
            [List removeObjectsForKeys:wrongRegionSites];
        }
    } 
    
    else 
    {
        List = AerodromeList.mutableCopy;
    }
    
	NSArray * UnitNames = [NSArray.alloc initWithArray:List.allKeys];
	NSString * ClosestUnit = UnitNames[0];
	
	CLLocation * ClosestUnitCoordinates = [CLLocation.alloc initWithLatitude:[[[List valueForKey:ClosestUnit] valueForKey:@"Latitude"] doubleValue]
                                                                   longitude:[[[List valueForKey:ClosestUnit] valueForKey:@"Longitude"] doubleValue]];	
	CLLocation * ComparaisonUnitCoordinates;
	
    for (NSString * ComparaisonUnit in UnitNames) 
    {
		ComparaisonUnitCoordinates = [CLLocation.alloc initWithLatitude:[[[List valueForKey:ComparaisonUnit] valueForKey:@"Latitude"] doubleValue]
                                                              longitude:[[[List valueForKey:ComparaisonUnit] valueForKey:@"Longitude"] doubleValue]];
		if ([ComparaisonUnitCoordinates distanceFromLocation:newLocation] < [ClosestUnitCoordinates distanceFromLocation:newLocation]) 
		{
			ClosestUnitCoordinates = [CLLocation.alloc initWithLatitude:ComparaisonUnitCoordinates.coordinate.latitude
                                                              longitude:ComparaisonUnitCoordinates.coordinate.longitude];
			ClosestUnit = ComparaisonUnit;
		}
		
	}
	
    if (Mode == NearestGC) 
    {
        [delegate updateGlidingCentreButton:ClosestUnit];
        [LocationFinder stopUpdatingLocation];
        
        if (regionIsUnknown) 
        {
            NSDictionary* unitInfo = List[ClosestUnit];
            NSString* Region = unitInfo[@"Region"];
            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
            [defaults setObject:Region forKey:@"Region"];
            [defaults synchronize];
            [self.delegate reloadFetchedResults:nil];
            
            NSNotification* refreshNotification = [NSNotification notificationWithName:@"RefreshAllViews" object:self  userInfo:nil];
            [NSNotificationCenter.defaultCenter postNotification:refreshNotification];
            
            NSString* errorText = [NSString.alloc
                                   initWithFormat:@"Your region has been set to %@ based on your closest known gliding centre. This can be changed in settings.",Region];
            
            
            UIAlertController* regionAlert = [UIAlertController alertControllerWithTitle:@"Region Set" message:errorText preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* OKbutton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [regionAlert addAction:OKbutton];
            
            UIViewController *rootController = (UIViewController *)((TimesheetsAppDelegate *)UIApplication.sharedApplication.delegate).window.rootViewController;
            
            if (rootController.presentedViewController)
            {
                [rootController.presentedViewController presentViewController:regionAlert animated:YES completion:nil];
            }
            
            else
            {
                [rootController presentViewController:regionAlert animated:YES completion:nil];
            }
        }
    }
    
    if (Mode == XcountryStart) 
    {
        NSString* NewRoute = [NSString.alloc initWithFormat:@"%@-?",ClosestUnit];
        
        if (![self.RecordToUpdate.transitRoute isEqualToString:NewRoute]) 
        {
            self.RecordToUpdate.transitRoute = NewRoute;
            [delegate saveContext];

        }
        
        if ([NSDate.date timeIntervalSinceDate:startOfMeasurement] > 60) 
        {
            [LocationFinder stopUpdatingLocation];
        }
        
        else 
        {
            return;
        }
    }
    
    if (Mode == XcountryEnd) 
    {
        NSString* RouteSoFar = self.RecordToUpdate.transitRoute;
        NSRange Placeholder = [RouteSoFar rangeOfString:@"-"];
        if (Placeholder.location == NSNotFound) 
        {
            self.RecordToUpdate.transitRoute = @"Transit";
        }
        
        else
        {
            NSString* oldDestination = [RouteSoFar substringFromIndex:(Placeholder.location + 1)];
            Placeholder = [RouteSoFar rangeOfString:oldDestination];
            
            NSString* UpdatedRoute = [RouteSoFar stringByReplacingCharactersInRange:Placeholder withString:ClosestUnit];
            
            if (![self.RecordToUpdate.transitRoute isEqualToString:UpdatedRoute]) 
            {
                self.RecordToUpdate.transitRoute = UpdatedRoute;
                [delegate saveContext];
                
            }
        }
        
        if ([NSDate.date timeIntervalSinceDate:startOfMeasurement] > 60) 
        {
            [LocationFinder stopUpdatingLocation];
        }
        
        else 
        {
            return;
        }
    }
    	
	return;
}

@end