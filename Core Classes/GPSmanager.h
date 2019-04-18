//
//  GPSmanager.h
//  Timesheets
//
//  Created by Paul Kirvan on 19/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "Constants.h"
@class FlightRecord;

@protocol GPSmanagerDelegate
-(void) updateGlidingCentreButton:(NSString*)Unit;
-(void) saveContext;
-(void) reloadFetchedResults:(NSNotification*)note;
@end

@interface GPSmanager : NSObject <CLLocationManagerDelegate>
{
    CLLocationManager * LocationFinder;
    NSDictionary * UnitList;
    NSDictionary * AerodromeList;
    GPSmode Mode;
    NSDate* startOfMeasurement;
    NSTimer*timeToEndLocationUpdates;
}

@property (nonatomic, weak) id <GPSmanagerDelegate> delegate;
@property (nonatomic, retain) FlightRecord* RecordToUpdate;

- (void) UpdateGlidingCentre;
- (void) AddXcountryStart:(FlightRecord*) Record;
- (void) AddXcountryEnd:(FlightRecord*) Record;
- (void) InitializeAerodromeList;

@end
