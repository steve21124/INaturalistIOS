//
//  ConfirmPhotoViewController.m
//  iNaturalist
//
//  Created by Alex Shepard on 2/25/15.
//  Copyright (c) 2015 iNaturalist. All rights reserved.
//

#import <SVProgressHUD/SVProgressHUD.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <BlocksKit/BlocksKit.h>
#import <BlocksKit/BlocksKit+UIKit.h>
#import <FontAwesomeKit/FAKFontAwesome.h>

#import "ConfirmPhotoViewController.h"
#import "Taxon.h"
#import "TaxonPhoto.h"
#import "ImageStore.h"
#import "Observation.h"
#import "ObservationPhoto.h"
#import "MultiImageView.h"
#import "ObservationDetailViewController.h"
#import "TaxaSearchViewController.h"
#import "UIColor+ExploreColors.h"
#import "CategorizeViewController.h"
#import "Observation.h"
#import "Observation+AddAssets.h"
#import "Analytics.h"
#import "Project.h"
#import "ProjectObservation.h"

#define CHICLETWIDTH 100.0f
#define CHICLETHEIGHT 98.0f
#define CHICLETPADDING 2.0

@interface ConfirmPhotoViewController () <ObservationDetailViewControllerDelegate, TaxaSearchViewControllerDelegate> {
    MultiImageView *multiImageView;
    ALAssetsLibrary *lib;
    UIButton *retake, *confirm;
    NSArray *iconicTaxa;
}
@end

@implementation ConfirmPhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // make sure we have some local iconic taxa before we try to categorize
    // if we don't have any, try to load remotely
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kInatCategorizeNewObsPrefKey]) {
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Taxon"];
        request.sortDescriptors = @[ [[NSSortDescriptor alloc] initWithKey:@"defaultName" ascending:YES] ];
        [request setPredicate:[NSPredicate predicateWithFormat:@"isIconic == YES"]];
        
        NSError *fetchError;
        iconicTaxa = [[NSManagedObjectContext defaultContext] executeFetchRequest:request
                                                                            error:&fetchError];

        if (iconicTaxa.count == 0) {
            [self loadRemoteIconicTaxa];
        }
        
    }
    
    if (!self.confirmFollowUpAction) {
        __weak __typeof__(self) weakSelf = self;
        self.confirmFollowUpAction = ^(NSArray *confirmedAssets){
            
            __strong typeof(weakSelf)strongSelf = weakSelf;

            if ([[NSUserDefaults standardUserDefaults] boolForKey:kInatCategorizeNewObsPrefKey] && iconicTaxa.count > 0 && !self.taxon) {
                // categorize the new observation before making it
                CategorizeViewController *categorize = [[CategorizeViewController alloc] initWithNibName:nil bundle:nil];
                categorize.assets = confirmedAssets;
                if (strongSelf.project) {
                    categorize.project = strongSelf.project;
                }
                categorize.shouldContinueUpdatingLocation = weakSelf.shouldContinueUpdatingLocation;
                [weakSelf transitionToCategorize:categorize];
            } else {
                // go straight to making the observation
                Observation *o = [Observation object];
                
                if (strongSelf.taxon) {
                    o.taxon = strongSelf.taxon;
                    o.speciesGuess = strongSelf.taxon.defaultName ?: strongSelf.taxon.name;
                }
                
                if (strongSelf.project) {
                    ProjectObservation *po = [ProjectObservation object];
                    po.observation = o;
                    po.project = strongSelf.project;
                }
                
                UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
                ObservationDetailViewController *detail = [storyboard instantiateViewControllerWithIdentifier:@"ObservationDetailViewController"];
                
                detail.delegate = weakSelf;
                detail.shouldShowBigSaveButton = YES;
                if (weakSelf.shouldContinueUpdatingLocation)
                    [detail startUpdatingLocation];
                
                [o addAssets:confirmedAssets];
                detail.observation = o;
                
                [weakSelf.navigationController setNavigationBarHidden:NO animated:YES];
                [weakSelf.navigationController pushViewController:detail animated:YES];
            }
        };
    }
    
    lib = [[ALAssetsLibrary alloc] init];
    
    multiImageView = ({
        MultiImageView *iv = [[MultiImageView alloc] initWithFrame:CGRectZero];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        
        iv.borderColor = [UIColor blackColor];
        
        iv;
    });
    [self.view addSubview:multiImageView];
    
    retake = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectZero;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        
        button.tintColor = [UIColor whiteColor];
        button.backgroundColor = [UIColor blackColor];
        button.layer.borderColor = [UIColor grayColor].CGColor;
        button.layer.borderWidth = 1.0f;
        
        [button setTitle:NSLocalizedString(@"Retake", @"Retake a photo")
                forState:UIControlStateNormal];
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        
        [button bk_addEventHandler:^(id sender) {
            [[Analytics sharedClient] event:kAnalyticsEventNewObservationRetakePhotos];
            [self.navigationController popViewControllerAnimated:YES];
            if (self.assets)
                [self.navigationController setNavigationBarHidden:NO];
        } forControlEvents:UIControlEventTouchUpInside];
        
        button;
    });
    [self.view addSubview:retake];
    
    confirm = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectZero;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        
        button.tintColor = [UIColor whiteColor];
        button.backgroundColor = [UIColor blackColor];
        
        button.layer.borderColor = [UIColor grayColor].CGColor;
        button.layer.borderWidth = 1.0f;
        
        [button setTitle:NSLocalizedString(@"Confirm", @"Confirm a new photo")
                forState:UIControlStateNormal];
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        
        [button bk_addEventHandler:^(id sender) {
            
            [[Analytics sharedClient] event:kAnalyticsEventNewObservationConfirmPhotos];
            
            if (self.image) {
                // we need to save to the AssetsLibrary...
                [SVProgressHUD showWithStatus:NSLocalizedString(@"Saving new photo...", @"status while saving your image")];
                // embed geo
                CLLocationManager *loc = [[CLLocationManager alloc] init];
                NSMutableDictionary *mutableMetadata = [self.metadata mutableCopy];
                if (loc.location) {
                    
                    double latitude = fabs(loc.location.coordinate.latitude);
                    double longitude = fabs(loc.location.coordinate.longitude);
                    NSString *latitudeRef = loc.location.coordinate.latitude > 0 ? @"N" : @"S";
                    NSString *longitudeRef = loc.location.coordinate.longitude > 0 ? @"E" : @"W";
                    
                    NSDictionary *gps = @{ @"Latitude": @(latitude), @"Longitude": @(longitude),
                                           @"LatitudeRef": latitudeRef, @"LongitudeRef": longitudeRef };
                    
                    mutableMetadata[@"{GPS}"] = gps;
                }
                
                [lib writeImageToSavedPhotosAlbum:self.image.CGImage
                                         metadata:mutableMetadata
                                  completionBlock:^(NSURL *newAssetUrl, NSError *error) {
                                      if (error) {
                                          [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error saving image: %@",
                                                                              error.localizedDescription]];
                                          [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                                      } else {
                                          [SVProgressHUD dismiss];
                                          
                                          [lib assetForURL:newAssetUrl
                                               resultBlock:^(ALAsset *asset) {
                                                   
                                                   // be defensive
                                                   if (asset) {
                                                       self.confirmFollowUpAction(@[ asset ]);
                                                   } else {
                                                       [[Analytics sharedClient] debugLog:@"error loading newly saved asset"];
                                                       [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Error using newly saved image!",
                                                                                                            @"Error message when we can't load a newly saved image")];
                                                   }
                                                   
                                               } failureBlock:^(NSError *error) {
                                                   [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error fetching asset: %@",
                                                                                       error.localizedDescription]];
                                                   [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                                               }];
                                          
                                      }
                                  }];
            } else if (self.assets) {
                // can proceed directly to followup
                self.confirmFollowUpAction(self.assets);
            }
            
        } forControlEvents:UIControlEventTouchUpInside];
        
        button;
    });
    [self.view addSubview:confirm];
    
    NSDictionary *views = @{
                            @"image": multiImageView,
                            @"confirm": confirm,
                            @"retake": retake,
                            };
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[image]-0-|"
                                                                      options:0
                                                                      metrics:0
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[retake]-0-[confirm(==retake)]-0-|"
                                                                      options:0
                                                                      metrics:0
                                                                        views:views]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[image]-0-[confirm(==60)]-0-|"
                                                                      options:0
                                                                      metrics:0
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[image]-0-[retake(==60)]-0-|"
                                                                      options:0
                                                                      metrics:0
                                                                        views:views]];
}


- (void)viewWillAppear:(BOOL)animated {
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.navigationController setToolbarHidden:YES animated:NO];
    
    if (self.image) {
        multiImageView.images = @[ self.image ];
    } else if (self.assets && self.assets.count > 0) {
        NSArray *images = [self.assets bk_map:^id(ALAsset *asset) {
            return [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
        }];
        multiImageView.images = images;
        multiImageView.hidden = NO;
    }
}

- (void)transitionToCategorize:(CategorizeViewController *)categorizeVC {
    [UIView animateWithDuration:0.1f
                     animations:^{
                         confirm.center = CGPointMake(confirm.center.x,
                                                      self.view.bounds.size.height + (confirm.frame.size.height / 2));
                         retake.center = CGPointMake(retake.center.x,
                                                     self.view.bounds.size.height + (retake.frame.size.height / 2));
                         multiImageView.frame = self.view.bounds;
                     } completion:^(BOOL finished) {
                         [self.navigationController pushViewController:categorizeVC
                                                              animated:NO];
                         
                         confirm.center = CGPointMake(confirm.center.x,
                                                      self.view.bounds.size.height - (confirm.frame.size.height / 2));
                         retake.center = CGPointMake(retake.center.x,
                                                     self.view.bounds.size.height - (retake.frame.size.height / 2));
                         
                     }];
}

#pragma mark - ObservationDetailViewController delegate

- (void)observationDetailViewControllerDidSave:(ObservationDetailViewController *)controller {
    [[Analytics sharedClient] event:kAnalyticsEventNewObservationSaveObservation];
    NSError *saveError;
    [[Observation managedObjectContext] save:&saveError];
    if (saveError) {
        [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error saving observation: %@",
                                            saveError.localizedDescription]];
        [SVProgressHUD showErrorWithStatus:saveError.localizedDescription];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)observationDetailViewControllerDidCancel:(ObservationDetailViewController *)controller {
    @try {
        [controller.observation destroy];
    } @catch (NSException *exception) {
        if ([exception.name isEqualToString:NSObjectInaccessibleException]) {
            // if observation has been deleted or is otherwise inaccessible, do nothing
            return;
        }
    }
}

#pragma mark - iNat API Request

- (void)loadRemoteIconicTaxa {
    // silently do nothing if we're offline
    if (![[[RKClient sharedClient] reachabilityObserver] isReachabilityDetermined] ||
        ![[[RKClient sharedClient] reachabilityObserver] isNetworkReachable]) {
        
        return;
    }
    
    [[RKObjectManager sharedManager] loadObjectsAtResourcePath:@"/taxa"
                                                    usingBlock:^(RKObjectLoader *loader) {
                                                        
                                                        loader.objectMapping = [Taxon mapping];
                                                        
                                                        loader.onDidLoadObjects = ^(NSArray *objects) {
                                                            
                                                            // update timestamps on us and taxa objects
                                                            NSDate *now = [NSDate date];
                                                            [objects enumerateObjectsUsingBlock:^(INatModel *o,
                                                                                                  NSUInteger idx,
                                                                                                  BOOL *stop) {
                                                                [o setSyncedAt:now];
                                                            }];
                                                            
                                                            // save into core data
                                                            NSError *saveError = nil;
                                                            [[[RKObjectManager sharedManager] objectStore] save:&saveError];
                                                            if (saveError) {
                                                                [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error saving object store: %@",
                                                                                                    saveError.localizedDescription]];
                                                                [SVProgressHUD showErrorWithStatus:saveError.localizedDescription];
                                                                return;
                                                            }
                                                            
                                                            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Taxon"];
                                                            request.sortDescriptors = @[ [[NSSortDescriptor alloc] initWithKey:@"defaultName" ascending:YES] ];
                                                            [request setPredicate:[NSPredicate predicateWithFormat:@"isIconic == YES"]];
                                                            
                                                            NSError *fetchError;
                                                            iconicTaxa = [[NSManagedObjectContext defaultContext] executeFetchRequest:request
                                                                                                                                error:&fetchError];
                                                            

                                                        };
                                                        
                                                        loader.onDidFailLoadWithError = ^(NSError *error) {
                                                            [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error loading: %@",
                                                                                                error.localizedDescription]];
                                                        };
                                                        
                                                        loader.onDidFailLoadWithError = ^(NSError *error) {
                                                            [[Analytics sharedClient] debugLog:[NSString stringWithFormat:@"error loading: %@",
                                                                                                error.localizedDescription]];
                                                        };
                                                        
                                                    }];
    
}


@end
