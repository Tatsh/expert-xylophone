#import "RBStoreManageCell.h"

// The whole class is a single strong @c button property on @c UITableViewCell. Under ARC every
// member is compiler-synthesised, so there are no hand-written method bodies:
//   - the @c button getter is at @ghidraAddress 0x1cd76c (a plain @c _button ivar load);
//   - @c setButton: is at @ghidraAddress 0x1cd77c (a retaining ivar store);
//   - @c .cxx_destruct is at @ghidraAddress 0x1cd7b4 (the ARC ivar teardown).
// The binary declares no initialiser override, so the cell is created with the inherited
// @c initWithStyle:reuseIdentifier: and carries no embedded __FILE__ path.
@implementation RBStoreManageCell

@end
