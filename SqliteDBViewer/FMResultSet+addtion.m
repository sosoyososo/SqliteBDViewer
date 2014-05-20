//
//  FMResultSet+addtion.m
//  SqliteDBViewer
//
//  Created by Karsa wang on 5/20/14.
//  Copyright (c) 2014 Karsa. All rights reserved.
//

#import "FMResultSet+addtion.h"
#import "FMDatabase.h"


@implementation FMResultSet (addtion)

- (NSUInteger)numOfRow {
    NSUInteger num_cols = (NSUInteger)sqlite3_data_count([[self statement] statement]);
    return num_cols;
}

@end
