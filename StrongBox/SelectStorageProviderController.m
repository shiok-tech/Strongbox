//
//  SelectStorageProviderController.m
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "SelectStorageProviderController.h"
#import "LocalDeviceStorageProvider.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "CustomStorageProviderTableViewCell.h"
#import "DatabaseModel.h"
#import "Alerts.h"
#import "StorageBrowserTableViewController.h"
#import "AppleICloudProvider.h"
#import "OneDriveStorageProvider.h"
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "FileManager.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "SharedAppAndAutoFillSettings.h"
#import "NSString+Extensions.h"

@interface SelectStorageProviderController () <UIDocumentPickerDelegate>

@property (nonatomic, copy, nonnull) NSArray<id<SafeStorageProvider>> *providers;

@end

@implementation SelectStorageProviderController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(self.existing) {
        [self.navigationItem setPrompt:NSLocalizedString(@"sspc_select_where_existing_stored", @"Select where your existing database is stored")];
    }
    else {
        [self.navigationItem setPrompt:NSLocalizedString(@"sspc_select_where_store_new", @"Select where you would like to store your new database")];
    }

    self.navigationController.toolbar.hidden = YES;
    self.navigationController.toolbarHidden = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    SFTPStorageProvider* sftpProviderWithFastListing = [[SFTPStorageProvider alloc] init];
    sftpProviderWithFastListing.maintainSessionForListing = YES;

    WebDAVStorageProvider* webDavProvider = [[WebDAVStorageProvider alloc] init];
    webDavProvider.maintainSessionForListings = YES;
    
    NSMutableArray<id<SafeStorageProvider>>* sp = @[GoogleDriveStorageProvider.sharedInstance,
                                                    DropboxV2StorageProvider.sharedInstance,
                                                    OneDriveStorageProvider.sharedInstance,
                                                    webDavProvider,
                                                    sftpProviderWithFastListing].mutableCopy;
    
    // iCloud on Top if available and want to add new
    
    if ([SharedAppAndAutoFillSettings sharedInstance].iCloudOn && !self.existing) {
        [sp insertObject:AppleICloudProvider.sharedInstance atIndex:0];
    }
    
    // iOS Files on iOS 11+ option at bottom near Local Device
    
    if (@available(iOS 11.0, *)) {
        [sp addObject:FilesAppUrlBookmarkProvider.sharedInstance];
    }
    
    // Local Device for Create New
    
    if (!self.existing) {
        [sp addObject:LocalDeviceStorageProvider.sharedInstance];
    }
    
    self.providers = sp.copy;
    
    self.tableView.tableFooterView = [UIView new];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.providers.count + (self.existing ? 2 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomStorageProviderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storageProviderReuseIdentifier" forIndexPath:indexPath];
    
    if(indexPath.row == self.providers.count) {
        cell.text.text = NSLocalizedString(@"sspc_copy_from_url_action", @"Copy from URL...");
        cell.image.image =  [UIImage imageNamed:@"Disconnect-32x32"];
    }
    else if(indexPath.row == self.providers.count + 1) {
        cell.text.text = NSLocalizedString(@"sspc_local_network_storage_location", @"Transfer Over Local Network");
        cell.image.image =  [UIImage imageNamed:@"wifi"];
    }
    else {
        id<SafeStorageProvider> provider = [self.providers objectAtIndex:indexPath.row];

        if (provider.storageId == kFilesAppUrlBookmark) {
            cell.text.text = NSLocalizedString(@"sspc_ios_files_storage_location", @"Files...");
            cell.image.image =  [UIImage imageNamed:@"folder"];
        }
        else {
            cell.text.text = provider.displayName;
            cell.image.image = [UIImage imageNamed:provider.icon];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row == self.providers.count) {
        [self initiateManualImportFromUrl];
    }
    else if(indexPath.row == self.providers.count + 1) {
        [self onAddThroughLocalNetworkServer];
    }
    else {
        id<SafeStorageProvider> provider = [_providers objectAtIndex:indexPath.row];
        
        if (provider.storageId == kFilesAppUrlBookmark) {
            if (self.existing) {
                [self onAddThroughFilesApp];
            }
            else {
                [self onCreateThroughFilesApp];
            }
        }
        else if (provider.storageId == kLocalDevice && !self.existing) {
            [Alerts yesNo:self
                    title:NSLocalizedString(@"sspc_local_device_storage_warning_title", @"Local Device Database Caveat")
                  message:NSLocalizedString(@"sspc_local_device_storage_warning_message", @"Since a local database is only stored on this device, any loss of this device will lead to the loss of all passwords stored within this database. You may want to consider using a cloud storage provider, such as the ones supported by Strongbox to avoid catastrophic data loss.\n\nWould you still like to proceed with creating a local device database?")
                   action:^(BOOL response) {
                       if (response) {
                           [self segueToBrowserOrAdd:provider];
                       }
                       else {
                           [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                       }
                   }];
        }
        else {
            [self segueToBrowserOrAdd:provider];
        }
    }
}

- (void)onAddThroughLocalNetworkServer {
    [self performSegueWithIdentifier:@"segueToLocalHttpServer" sender:nil];
}

- (void)initiateManualImportFromUrl {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:NSLocalizedString(@"sspc_manual_import_placeholder_url", @"URL")
                            title:NSLocalizedString(@"sspc_manual_import_enter_url_title", @"Enter URL")
                          message:NSLocalizedString(@"sspc_manual_import_enter_url_message", @"Please Enter the URL of the Database File.")
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSURL *url = text.urlExtendedParse;
                               NSLog(@"URL: %@", url);
                               
                               [self importFromManualUiUrl:url];
                           }
                       }];
}

- (void)onCreateThroughFilesApp {
    self.onDone([SelectedStorageParameters parametersForFilesApp:nil withProvider:FilesAppUrlBookmarkProvider.sharedInstance]);
}

- (void)onAddThroughFilesApp {
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeOpen];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Three different methods of adding/creating

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    
    self.onDone([SelectedStorageParameters parametersForFilesApp:url withProvider:FilesAppUrlBookmarkProvider.sharedInstance]);
}

- (void)importFromManualUiUrl:(NSURL *)importURL {
    NSError* error;
    NSData *importedData = [NSData dataWithContentsOfURL:importURL options:kNilOptions error:&error];  // FUTURE: Would be good not to have to read all file
    
    if(error) {
        [Alerts error:self
                title:NSLocalizedString(@"sspc_manual_import_error_title", @"Error Reading from URL")
                error:error];
        return;
    }
    
    if (![DatabaseModel isValidDatabaseWithPrefix:importedData error:&error] ) {
        [Alerts error:self
                title:NSLocalizedString(@"sspc_error_invalid_database", @"Invalid Database")
                error:error];
        
        return;
    }
    
    self.onDone([SelectedStorageParameters parametersForManualDownload:importedData]);
}

- (void)segueToBrowserOrAdd:(id<SafeStorageProvider>)provider {
    BOOL storageBrowseRequired = (self.existing && provider.browsableExisting) || (!self.existing && provider.browsableNew);

    if (storageBrowseRequired) {
        [self performSegueWithIdentifier:@"SegueToBrowser" sender:provider];
    }
    else {
        if(self.existing) {
            [Alerts info:self
                   title:@"Error Selecting Storage Provider"
                 message:@"Please contact support@strongboxsafe.com if you receive this message. It looks like there is a problem with this Storage provider"
              completion:^{
                self.onDone(SelectedStorageParameters.userCancelled); // Pretty sure this is unreachable...
            }];
        }
        else {
            self.onDone([SelectedStorageParameters parametersForNativeProviderCreate:provider folder:nil]);
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"SegueToBrowser"]) {
        StorageBrowserTableViewController *vc = segue.destinationViewController;
        
        vc.existing = self.existing;
        vc.safeStorageProvider = sender;
        vc.parentFolder = nil;
        vc.onDone = self.onDone;
    }
}

- (IBAction)onCancel:(id)sender {
    self.onDone([SelectedStorageParameters userCancelled]);
}

@end
