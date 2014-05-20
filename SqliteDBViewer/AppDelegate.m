//
//  AppDelegate.m
//  SqliteDBViewer
//
//  Created by Karsa wang on 5/6/14.
//  Copyright (c) 2014 Karsa. All rights reserved.
//

#import "AppDelegate.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet+addtion.h"

@interface DragingWindow : NSWindow <NSDraggingDestination>

@property (nonatomic, weak) id dragDelegate;

@end

@implementation DragingWindow

- (void)draggingEnded:(id <NSDraggingInfo>)sender {
    if ([self.dragDelegate respondsToSelector:@selector(draggingEnded:)]) {
        [self.dragDelegate draggingEnded:sender];
    }
}

@end

@interface NoDragingTextView : NSTextView

@end

@implementation NoDragingTextView

- (NSArray *)acceptableDragTypes
{
    return nil;
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    return NSDragOperationNone;
}
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationNone;
}

@end



@interface AppDelegate () <NSComboBoxDataSource, NSComboBoxDelegate, NSOpenSavePanelDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet              NSComboBox          *comboBox;
@property IBOutlet              NSTextField         *path;
@property IBOutlet              NoDragingTextView   *sqlContent;
@property IBOutlet              NSTableView         *resultTable;
@property (nonatomic, strong)   NSArray             *tableNames;
@property (nonatomic, strong)   FMDatabaseQueue     *dbQueue;
@property (nonatomic, strong)   NSString            *selectedTablName;
@property (nonatomic, strong)   NSArray             *result;
@property (nonatomic, strong)   NSArray             *resultKey;


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.window.dragDelegate = self;
    [self.window registerForDraggedTypes:@[NSFilenamesPboardType]];
    [self.sqlContent unregisterDraggedTypes];
}

#pragma mark - Private


- (void)setTableNames:(NSArray *)tableNames {
    _tableNames = tableNames;
    [self.comboBox removeAllItems];
    tableNames.count <= 0 ? : ([self.comboBox addItemsWithObjectValues:tableNames]);
}

- (IBAction)openDBFile:(id)sender {
    NSString *dataBaseFilePath = self.path.stringValue;
    if (dataBaseFilePath.length <= 0) {
        NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
        [openPanel setCanChooseFiles:YES];
        if ([openPanel runModal] == NSOKButton)
        {            
            dataBaseFilePath = [[openPanel URL] path];
        }
    }
    [self openPath:dataBaseFilePath];
}

- (void)openPath:(NSString *)dataBaseFilePath {
    if (dataBaseFilePath.length <= 0) {
        return;
    }
    self.path.stringValue = dataBaseFilePath;
    NSLog(@"%@",dataBaseFilePath);
    if (self.dbQueue) {
        [self.dbQueue close];
        self.dbQueue = nil;
    }
    self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:dataBaseFilePath];
    [self resetAllTables];
}


- (IBAction)excute:(id)sender {
    NSString *sqlStatement =  [[self.sqlContent textStorage] string];
    if (sqlStatement.length > 0 ) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:sqlStatement];
            if (nil == rs) {
                [db executeUpdate:sqlStatement];
            } else {
                self.resultKey = [[[rs columnNameToIndexMap] keyEnumerator] allObjects];
                
                NSMutableArray *result = [NSMutableArray array];
                while ([rs next]) {
                    [result addObject:[rs resultDictionary]];
                }
                self.result = result;
                
                [self resetResultTable];
            }
        }];
    }
}

- (void)resetAllTables {
    if (self.dbQueue) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:@"SELECT * FROM sqlite_master WHERE type ='table' "];
            NSMutableArray *tableNames = [NSMutableArray array];
            while ([rs next]) {
                NSDictionary *dict = [rs resultDictionary];
                [tableNames addObject:[dict objectForKey:@"tbl_name"]];
            }
            self.tableNames = tableNames;
        }];
    }
}

- (void)resetResultTable {
    if (self.result && self.resultKey) {
        
        NSArray *tableColumns = [self.resultTable tableColumns];
        NSUInteger tableColumnNum = tableColumns.count;
        NSUInteger columnNum = [self.resultKey count];
        
        if (columnNum < tableColumnNum) {
            int i = 0;
            for (NSTableColumn *column in tableColumns) {
                if (i >= columnNum) {
                    [self.resultTable removeTableColumn:column];
                } else {
                    [column setIdentifier:self.resultKey[i]];
                    [column.headerCell setPlaceholderString:self.resultKey[i]];
                }
                i ++;
            }
        } else if (columnNum >= tableColumnNum){
            for (int i = 0; i < columnNum; i ++) {
                NSTableColumn *column = i < tableColumnNum ? tableColumns[i] : nil;
                if (!column) {
                    column = [[NSTableColumn alloc] init];
                }
                [column setIdentifier:self.resultKey[i]];
                [column.headerCell setPlaceholderString:self.resultKey[i]];
            }
        }
        
        [self.resultTable reloadData];
    }
}

#pragma mark - NSComboBoxDelegate
- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedIndex = [self.comboBox indexOfSelectedItem];
    if (selectedIndex >= 0 && selectedIndex < self.tableNames.count) {
        self.selectedTablName = [self.tableNames objectAtIndex:[self.comboBox indexOfSelectedItem]];
        NSLog(@"select table : %@", self.selectedTablName);
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"select * from %@", self.selectedTablName]];
            
            self.resultKey = [[[rs columnNameToIndexMap] keyEnumerator] allObjects];
            
            NSMutableArray *result = [NSMutableArray array];
            while ([rs next]) {
                [result addObject:[rs resultDictionary]];
            }
            self.result = result;
            
            [self resetResultTable];
        }];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.result count];;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSDictionary *rowDict = self.result[row];
    return [[rowDict objectForKey:[tableColumn identifier]] description];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender {
    NSPasteboardItem *item = [[[sender draggingPasteboard] pasteboardItems] lastObject];
    if (item) {
        NSString *itemType = [[item types] lastObject];
        NSString *path = [item stringForType:itemType];
        
        [self openPath:path];
    }
}

@end
