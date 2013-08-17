//
//  ViewController.m
//  AFFNetworkingTestHarness
//
//  Created by Andrew Apperley on 2013-08-10.
//  Copyright (c) 2013 AFApps. All rights reserved.
//

#import "AFFNRequest.h"
#import "AFFNManager.h"
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
        AFFNRequest *request = [AFFNRequest requestWithURL:@"http://dev.andrewapperley.ca/aff/request_dump.php" connectionType:kAFFNMulti andParams:[NSDictionary dictionaryWithObjectsAndKeys:@"Andrew",@"name", nil] withCompletion:^(AFFNCallbackObject *result) {
            
            NSLog(@"TOTAL TIME: %f",result.totalRequestTime);
            
            NSString *resultString = [[[NSString alloc] initWithData:result.data encoding:NSStringEncodingConversionAllowLossy] autorelease];
            
            NSLog(@"RESULT: %@",resultString);
            
            
        } andFailBlock:^(NSError *error){
            NSLog(@"ERROR: %@",error);
        } andUpProgressBlock:^(float progress){
            NSLog(@"%f",progress);
        } andDProgressBlock:^(float progress){
            NSLog(@"%f",progress);
        } ];
    
//    request.multipartData = [NSArray arrayWithObjects:@"Hello",@"Sup",@"this is stuff", nil];
    request.multipartData = [NSArray arrayWithObjects:[[NSString stringWithFormat:@"DATA TEXT"] dataUsingEncoding:NSUTF8StringEncoding], [[NSString stringWithFormat:@"THIS IS TEXT AS DATA"] dataUsingEncoding:NSUTF8StringEncoding], nil];
        [[AFFNManager sharedManager] addNetworkOperation:request];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
