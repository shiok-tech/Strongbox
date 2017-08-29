//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "Alerts.h"
#import "ChangeMasterPasswordWindowController.h"
#import "Settings.h"
#import "AppDelegate.h"

#define kDragAndDropUti @"com.markmcguill.strongbox.drag.and.drop.internal.uti"

@interface ViewController ()

@property (strong, nonatomic) ChangeMasterPasswordWindowController *changeMasterPassword;
@property (strong, nonatomic) NSImage *folderImage;
@property (strong, nonatomic) NSImage *strongBox256Image;
@property (strong, nonatomic) NSImage *smallYellowFolderImage;
@property (strong, nonatomic) NSImage *smallLockImage;
@property (nonatomic) BOOL showPassword;
@property (nonatomic) NSString* hiddenPasswordTemporaryStore;

@end

@implementation ViewController

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self initializeFullOrTrialOrLiteUI];
    
    [self setInitialFocus];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self loadUIImages];
    
    [self enableDragDrop];

    [self customizeUi];

    [self bindToModel];
}

- (void)customizeUi {
    self.buttonRevealDetails.layer.cornerRadius = 20;
    self.checkboxRevealDetailsImmediately.state = [Settings sharedInstance].revealDetailsImmediately;
    
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
}

- (void)loadUIImages {
    self.folderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
    self.strongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
    self.smallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
    self.smallLockImage = [NSImage imageNamed:@"lock-48"];
}

- (void)disableFeaturesForLiteVersion {
    [self.searchField setPlaceholderString:@"Search Disabled - Please Upgrade"];
    self.searchField.enabled = NO;
    self.searchSegmentedControl.enabled = NO;
}

- (void)enableFeaturesForFullVersion {
    [self.searchField setPlaceholderString:@"Search (⌘F)"];
    self.searchField.enabled = YES;
    self.searchSegmentedControl.enabled = YES;
}

- (void)initializeFullOrTrialOrLiteUI {
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial) {
        [self disableFeaturesForLiteVersion];
    }
    else {
        [self enableFeaturesForFullVersion];
    }
}

-(void)setModel:(ViewModel *)model {
    _model = model;
    [self bindToModel];
}

-(void)updateDocumentUrl {
    self.labelLeftStatus.stringValue = [NSString stringWithFormat:@"%@", self.model.fileUrl ? self.model.fileUrl : @"[Not Saved]"];
}

- (void)bindToModel {
    if(self.model == nil) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
        
        [self.outlineView reloadData];
        
        return;
    }
    
    if(self.model.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
    }
    else {        
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
    }
    
    [self.outlineView reloadData];

    if([self.outlineView numberOfRows] > 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    [self bindDetailsPane];

    [self updateDocumentUrl];
}

- (void)setInitialFocus {
    if(self.model == nil || self.model.locked) {
        [self.view.window makeFirstResponder:self.textFieldMasterPassword];
    }
    else {
        [self.view.window makeFirstResponder:self.outlineView];
    }
}

- (void)bindDetailsPane {
    SafeItemViewModel* it = [self getCurrentSelectedItem];
    
    if(!it) {
        self.textFieldTitle.stringValue = @"";
        self.textFieldPw.stringValue = @"";
        self.textFieldUrl.stringValue = @"";
        self.textFieldUsername.stringValue = @"";
        self.textViewNotes.string = @"";
        self.imageViewSummary.image = self.strongBox256Image;
        self.textFieldSummaryTitle.stringValue= @"";
        
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        self.stackViewRevealButton.hidden = YES;
    }
    else if (it.isGroup) {
        self.textFieldTitle.stringValue = @"";
        self.textFieldPw.stringValue = @"";
        self.textFieldUrl.stringValue = @"";
        self.textFieldUsername.stringValue = @"";
        self.textViewNotes.string = @"";
        
        self.imageViewSummary.image = self.folderImage;
        self.textFieldSummaryTitle.stringValue = it.title;
        
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        
        self.stackViewRevealButton.hidden = YES;
    }
    else {
        self.textFieldTitle.stringValue = it.title;
        self.textFieldPw.stringValue = it.password;
        self.textFieldUrl.stringValue = it.url;
        self.textFieldUsername.stringValue = it.username;
        self.textViewNotes.string = it.notes;

        self.imageViewSummary.image = self.strongBox256Image;
        self.textFieldSummaryTitle.stringValue = it.title;
        
        if([Settings sharedInstance].revealDetailsImmediately) {
            [self revealDetails];
        }
        else {
            [self concealDetails];
        }
        
        [self showOrHidePassword];
    }
}

- (IBAction)onRevealDetails:(id)sender {
    [self revealDetails];
}

- (IBAction)onConcealDetails:(id)sender {
    [self concealDetails];
}

- (void)revealDetails {
        [self.tabViewRightPane selectTabViewItemAtIndex:0];
}

- (void)concealDetails {
    [self.tabViewRightPane selectTabViewItemAtIndex:1];
    self.stackViewRevealButton.hidden = NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.model || self.model.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<SafeItemViewModel*> *items = [self getSafeItems:nil];
        
        return items.count > 0;
    }
    else {
        SafeItemViewModel *it = (SafeItemViewModel*)item;
        
        if(it.isGroup) {
            NSArray<SafeItemViewModel*> *items = [self getSafeItems:it.group];
            
            return items.count > 0;
        }
        else {
            return NO;
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if(!self.model || self.model.locked) {
        return 0;
    }
    
    Group* group = (item == nil) ? nil : ((SafeItemViewModel*)item).group;
    
    NSArray<SafeItemViewModel*> *items = [self getSafeItems:group];
    
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    Group* group = (item == nil) ? nil : ((SafeItemViewModel*)item).group;
    
    NSArray<SafeItemViewModel*> *items = [self getSafeItems:group];
    
    return items[index];
}

- (NSArray<SafeItemViewModel*> *)getSafeItems:(Group*)parentGroup {
    if(!self.model || self.model.locked) {
        NSLog(@"Request for safe items while model nil or locked!");
        return @[];
    }
    
    NSArray<SafeItemViewModel*> *items = [self.model getItemsForGroup:parentGroup];
    
    return [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self isSafeItemMatchesSearchCriteria:evaluatedObject];
    }]];
}

- (BOOL)isSafeItemMatchesSearchCriteria:(SafeItemViewModel*)item {
    NSString* searchText = self.searchField.stringValue;
    
    if(![searchText length]) {
        return YES;
    }
    
    NSPredicate *predicate;
    
    NSInteger scope = self.searchSegmentedControl.selectedSegment;
    if (scope == 0) {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    else if (scope == 1)
    {
        predicate = [NSPredicate predicateWithFormat:@"username contains[c] %@", searchText];
    }
    else if (scope == 2)
    {
        predicate = [NSPredicate predicateWithFormat:@"password contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ OR password contains[c] %@  OR username contains[c] %@  OR url contains[c] %@  OR notes contains[c] %@", searchText, searchText, searchText, searchText, searchText];
    }

    if([predicate evaluateWithObject:item]) {
        return YES;
    }
    else if(item.isGroup) {
        return [[self getSafeItems:item.group] count] > 0;
    }
    
    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item
{
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
    NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"CellIdentifier" owner:self];

    SafeItemViewModel *it = (SafeItemViewModel*)item;
    
    cell.textField.stringValue = it.title;
    cell.imageView.objectValue = it.isGroup ? self.smallYellowFolderImage : self.smallLockImage;
    
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    //NSLog(@"Selection Change Outline View");
    SafeItemViewModel* item =  [self getCurrentSelectedItem];
    
    self.hiddenPasswordTemporaryStore = item == nil || item.isGroup ? nil : item.password;
    
    [self bindDetailsPane];
}

- (IBAction)onEnterMasterPassword:(id)sender {
    [self unlock];
}

- (IBAction)onUnlock:(id)sender {
    [self unlock];
}

- (void)unlock {
    if(self.model && self.model.locked) {
        NSError *error;
        NSString *selectedItemId;
        
        if([self.model unlock:self.textFieldMasterPassword.stringValue selectedItem:&selectedItemId error:&error]) {
            [self bindToModel];
            
            self.textFieldMasterPassword.stringValue = @"";
            
            SafeItemViewModel* selectedItem = [self.model getItemFromSerializationId:selectedItemId];
            
            [self selectItem:selectedItem];
            
            [self setInitialFocus];
        }
        else {
            [Alerts error:@"Could not open safe" error:error window:self.view.window];
        }
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        if(self.model.dirty) {
            [Alerts info:@"You cannot lock a safe while changes are pending. Save your changes first." window:self.view.window];
            //            NSLog(@"Saving...");
            //            
            //            SEL selector = NSSelectorFromString(@"saveDocument:");
            //            [[NSApplication sharedApplication] sendAction:selector to:nil from:self];
            //            
            //[NSApplication sharedApplication] sendAction:NSSelectorFromString(saveDocument: to:]; from:(nullable id)
        }
        else {
            NSError* error;
            
            SafeItemViewModel* item = [self getCurrentSelectedItem];
            NSString *selectedItemId = [self.model getSerializationIdForItem:item];
            
            if(![self.model lock:&error selectedItem:selectedItemId]) {
                [Alerts error:error window:self.view.window];
                return;
            }
            
            [self bindToModel];
            
            self.textFieldMasterPassword.stringValue = @"";
            [self setInitialFocus];
        }
    }
}

- (IBAction)onOutlineViewDoubleClick:(id)sender {
    SafeItemViewModel *item = [sender itemAtRow:[sender clickedRow]];
    
    if ([sender isItemExpanded:item]) {
        [sender collapseItem:item];
    }
    else {
        [sender expandItem:item];
    }
}

- (IBAction)onFind:(id)sender {
    [self.view.window makeFirstResponder:self.searchField];
}

- (IBAction)onChangeMasterPassword:(id)sender {
    if(self.model && !self.model.locked) {
        self.changeMasterPassword = [[ChangeMasterPasswordWindowController alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
        
        self.changeMasterPassword.titleText = @"Change Master Password";
        
        [self.view.window beginSheet:self.changeMasterPassword.window  completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSModalResponseOK) {
                [self.model setMasterPassword:self.changeMasterPassword.confirmedPassword];
                [Alerts info:@"Master Password Changed" window:self.view.window];
            }
        }];
    }
}

- (IBAction)onSearch:(id)sender {
    //NSLog(@"Search For: %@", self.searchField.stringValue);
    
    [self.outlineView reloadData];
    
    if( self.searchField.stringValue.length > 0) {
        [self.outlineView expandItem:nil expandChildren:YES];
    }
    else {
        [self.outlineView collapseItem:nil collapseChildren:YES];
    }
    
    [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
}

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender {
    [Settings sharedInstance].revealDetailsImmediately = self.checkboxRevealDetailsImmediately.state;
}

- (IBAction)onToggleShowHidePassword:(id)sender {
    self.showPassword = !self.showPassword;
    
    [self showOrHidePassword];
}

- (void)showOrHidePassword {
    if(self.showPassword) {
        self.textFieldPw.enabled = YES;
        self.textFieldPw.stringValue = self.hiddenPasswordTemporaryStore;
        self.buttonShowHidePassword.title = @"Hide Password (⌘P)";
    }
    else {
        self.hiddenPasswordTemporaryStore = self.textFieldPw.stringValue;
        self.textFieldPw.enabled = NO;
        self.textFieldPw.stringValue = @"***********************";
        self.buttonShowHidePassword.title = @"Show Password (⌘P)";
    }
}

- (IBAction)onCopyTitle:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldTitle.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUsername:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldUsername.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldUrl.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyNotes:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textViewNotes.textStorage.string forType:NSStringPboardType];
}

- (IBAction)onCopyPassword:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];
}

- (SafeItemViewModel*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    //NSLog(@"Selected Row: %ld", (long)selectedRow);
    
    return [self.outlineView itemAtRow:selectedRow];
}

- (IBAction)controlTextDidChange:(NSNotification *)obj
{
    //NSLog(@"controlTextDidChange");
    [self onDetailFieldChange:obj.object];
}

- (void)textDidChange:(NSNotification *)notification {
    //NSLog(@"textDidChange");
    
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    SafeItemViewModel* item = [self getCurrentSelectedItem];
    if(notification.object == self.textViewNotes && ![item.notes isEqualToString:self.textViewNotes.textStorage.string]) {
        //NSLog(@"Notes Changed");
        [self.model setItemNotes:item notes:self.textViewNotes.textStorage.string];
    }
}

// Old code for when edit ends and user tabs out
//- (IBAction)onTextEdited:(id)sender {
//    //NSLog(@"onTextEdited");
//    //[self onDetailFieldChange:sender];
//}
//
//- (void)textDidEndEditing:(NSNotification *)notification {
//
//}

- (IBAction)onDetailFieldChange:(id)sender {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    SafeItemViewModel* item = [self getCurrentSelectedItem];
    
    if(sender == self.textFieldTitle) {
        if(![item.title isEqualToString:trimField(self.textFieldTitle)]) {
            //NSLog(@"Title Changed!");
            [self.model setItemTitle:item title:trimField(self.textFieldTitle)];
            
            NSInteger row = [self.outlineView selectedRow];
            [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            // self.textFieldTitle.stringValue = trimField(self.textFieldTitle);
        }
    }
    else if(sender == self.textFieldUsername) {
        if(![item.username isEqualToString:trimField(self.textFieldUsername)]) {
            //NSLog(@"Username Changed!");
            [self.model setItemUsername:item username:trimField(self.textFieldUsername)];
            // self.textFieldUsername.stringValue = trimField(self.textFieldUsername);
        }
    }
    else if(sender == self.textFieldUrl) {
        if(![item.url isEqualToString:trimField(self.textFieldUrl)]) {
            //NSLog(@"Url Changed!");
            [self.model setItemUrl:item url:trimField(self.textFieldUrl)];
            // self.textFieldUrl.stringValue = trimField(self.textFieldUrl);
        }
    }
    else if(sender == self.textFieldPw) {
        if(![item.password isEqualToString:trimField(self.textFieldPw)]) {
            //NSLog(@"Password Changed!");
            [self.model setItemPassword:item password:trimField(self.textFieldPw)];
            // self.textFieldPw.stringValue = trimField(self.textFieldPw);
        }
    }
}

- (IBAction)onOutlineViewItemEdited:(id)sender {
    SafeItemViewModel *item = [self getCurrentSelectedItem];
    
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;

    if(![item.title isEqualToString:trimField(textField)]) {
        SafeItemViewModel *newlyNamedItem = [self.model setItemTitle:item title:trimField(textField)];

        [self reloadDataAndSelectItem:newlyNamedItem];
         
        [self bindDetailsPane];
    }
    else {
        textField.stringValue = trimField(textField);
    }
}

NSString* trimField(NSTextField* textField) {
    return trim(textField.stringValue);
}

NSString* trim(NSString* str) {
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)expandParentsOfItem:(SafeItemViewModel*)item {
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    
    while (!item.isRootGroup) {
        item = [item getParentGroup];
        
        //NSLog(@"Got Parent == %@", i.title);
        
        [stack addObject:item];
    }
    
    while ([stack count]) {
        SafeItemViewModel *group = [stack lastObject];
        
        //NSLog(@"Expanding %@", group.title);
        [self.outlineView expandItem:group];
        
        [stack removeObject:group];
    }
}

- (NSInteger)findRowForItemExpandIfNecessary:(id)item {
    NSInteger itemIndex = [self.outlineView rowForItem:item];
    
    if (itemIndex < 0) {
        [self expandParentsOfItem: item];
        
        itemIndex = [self.outlineView rowForItem:item];
        
        if (itemIndex < 0) {
            return itemIndex;
        }
    }
    
    return itemIndex;
}

- (void)reloadDataAndSelectItem:(SafeItemViewModel*)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.outlineView reloadData];
        
        [self selectItem:item];
    });
}
                   
- (void)selectItem:(SafeItemViewModel*)item {
    if(item) {
        NSInteger row = [self findRowForItemExpandIfNecessary:item];
        
        if(row >= 0) {
            [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        }
        else {
            NSLog(@"Could not find item row for selection to maintain");
        }
    }
}

- (void)enableDragDrop {
    [self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:kDragAndDropUti]];
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item {
    NSPasteboardItem *paste = [[NSPasteboardItem alloc] init];
    
    NSString* serializationItem = [self.model getSerializationIdForItem:item];
    NSLog(@"pasteboardWriterForItem %@ => [%@]", ((SafeItemViewModel*)item).title, serializationItem);
    
    [paste setString:serializationItem forType:kDragAndDropUti];

    return paste;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index
{
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];

    SafeItemViewModel* sourceItem = [self.model getItemFromSerializationId:itemId];
    SafeItemViewModel* destinationItem = (item == nil) ? [[SafeItemViewModel alloc] initAsRootGroup] : item;
    
    //NSLog(@"validate Move [%@] [%@] -> [%@]", itemId, sourceItem, destinationItem);
    
    NSArray<SafeItemViewModel*>* sourceItems = [NSArray arrayWithObject:sourceItem];
    BOOL valid = !destinationItem ||
        (destinationItem.isGroup && [self.model validateMoveOfItems:sourceItems group:destinationItem]);
    
    return valid ? NSDragOperationMove : NSDragOperationNone;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info
              item:(id)item
        childIndex:(NSInteger)index {
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];
    SafeItemViewModel* sourceItem = [self.model getItemFromSerializationId:itemId];
    SafeItemViewModel* destinationItem = (item == nil) ? [[SafeItemViewModel alloc] initAsRootGroup] : item;
    
    NSLog(@"acceptDrop Move [%@] -> [%@]", sourceItem, destinationItem);
    
    NSArray<SafeItemViewModel*>* sourceItems = [NSArray arrayWithObject:sourceItem];
    
    if([self.model moveItems:sourceItems group:destinationItem]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.outlineView reloadData];
        });
        
        return YES;
    }
    
    return NO;
}

- (IBAction)onCreateRecord:(id)sender {
    SafeItemViewModel *item = [self getCurrentSelectedItem];
    SafeItemViewModel *newItem = [self.model addNewRecord:item.isGroup ? item.group : item.record.group];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
        if ([cellView.textField acceptsFirstResponder]) {
            [cellView.window makeFirstResponder:cellView.textField];
        }
    }
}

- (IBAction)onCreateGroup:(id)sender {
    SafeItemViewModel *item = [self getCurrentSelectedItem];
    SafeItemViewModel *newItem = [self.model addNewGroup:item.isGroup ? item.group : item.record.group];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
        if ([cellView.textField acceptsFirstResponder]) {
            [cellView.window makeFirstResponder:cellView.textField];
        }
    }
}

- (IBAction)onDelete:(id)sender {
    SafeItemViewModel *item = [self getCurrentSelectedItem];
    
    if(!item) {
        return;
    }
    
    [Alerts yesNo:@"Are you sure you want to delete this item?" window:self.view.window completion:^(BOOL yesNo) {
        if(yesNo) {
            [self.model deleteItem:item];
            
            [self.outlineView reloadData];
            
            [self bindDetailsPane];
        }
    }];
}

- (IBAction)onLaunchUrl:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:self.textFieldUrl.stringValue]];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];

    [self onLaunchUrl:sender];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];
    
    SafeItemViewModel* item = [self getCurrentSelectedItem];
    
    if (theAction == @selector(onDelete:)) {
        return item != nil;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onCreateGroup:) ||
             theAction == @selector(onCreateRecord:) ||
             theAction == @selector(onLock:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onFind:)) {
        return self.model && !self.model.locked &&
        ([Settings sharedInstance].fullVersion || [Settings sharedInstance].freeTrial);
    }
    else if(theAction == @selector(onLaunchUrl:) ||
            theAction == @selector(onCopyUrl:)) {
        return item && !item.isGroup && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyTitle:)) {
        return item && !item.isGroup && self.textFieldTitle.stringValue.length;
    }
    else if (theAction == @selector(onCopyUsername:)) {
        return item && !item.isGroup && self.textFieldUsername.stringValue.length;
    }
    else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
        NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
        
        return item && !item.isGroup && password.length && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyPassword:)) {
        NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
        return item && !item.isGroup && password.length;
    }
    else if (theAction == @selector(onCopyNotes:)) {
        return item && !item.isGroup && self.textViewNotes.textStorage.string.length;
    }
    
    return YES;
}

- (IBAction)onGenerate:(id)sender {
    self.showPassword = YES;
    [self showOrHidePassword];

    self.textFieldPw.stringValue = [self.model generatePassword];
    
    [self onDetailFieldChange:self.textFieldPw];
}

@end