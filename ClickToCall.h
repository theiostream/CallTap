/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Kool story bro
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

@interface ABModel : NSObject
- (ABRecordRef)displayedMemberAtIndex:(NSInteger)index;
@end

@interface UIApplication (ClickToCall)
- (void)applicationOpenURL:(NSURL *)url;
@end

@interface UIActionSheet (ClickToCall)
- (void)_addButtonWithTitle:(id)arg1 label:(id)arg2;
@end

@interface ABMemberCell : UITableViewCell
@end

@interface ABMembersDataSource : NSObject
- (id)delegate;
- (ABModel *)model;
- (ABRecordRef)recordWithGlobalIndex:(NSInteger)globalIndex;
@end

@interface ABMembersController : NSObject
- (void)abDataSource:(ABMembersDataSource *)dataSource selectedPerson:(ABRecordRef)person atIndexPath:(NSIndexPath *)indexPath withMemberCell:(UITableViewCell *)cell animate:(BOOL)animated;
@end

@interface UITableViewRowData : NSObject
- (NSInteger)globalRowForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface UITableView (ClickToCall)
- (UITableViewRowData *)_rowData;
@end