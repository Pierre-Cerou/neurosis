//
//  NeurosisController.m
//  Neurosis
//
//  Created by Patrick B. Gibson on 01/04/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NeurosisController.h"

#import "PBGDefines.h"

#import "PBGImageAndTextCell.h"
#import "PBGTreeNode.h"
#import "PBGLesson.h"


#define kMinOutlineViewSplit		125.0f
#define kSourcesColumnIdentifier	@"SOURCES"

#define kInputsFolderIdentifier		@"INPUTS"
#define kEducationFolderIdentifier	@"EDUCATION"
#define kCameraIdentifier			@"Camera"


#define kFilePrefix					@"file://"
#define HTTP_PREFIX					@"http://"

@implementation NeurosisController

- (id)init
{
	self = [super init];
	if (self != nil) {
		contents = [[NSMutableArray alloc] init];
		
		// Get the images for our camera and for our images
		cameraIconImage = [[[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Image Capture.app"] copy];
		[cameraIconImage setSize:NSMakeSize(16,16)];
		[cameraIconImage retain];
		photoIconImage = [[[NSWorkspace sharedWorkspace] iconForFileType:@"jpg"] retain];
		[photoIconImage setSize:NSMakeSize(16,16)];
	}
	return self;
}

- (void)awakeFromNib
{
	[[NSApplication sharedApplication] setDelegate:self];
	
	// Apply our custom ImageAndTextCell for rendering the first column's cells
	NSTableColumn *tableColumn = [sourceListView tableColumnWithIdentifier:kSourcesColumnIdentifier];
	PBGImageAndTextCell *imageAndTextCell = [[[PBGImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];

	
	cameraController = [[CameraController alloc] initWithNibName:@"Camera" bundle:nil];
	//lessonContoller = [[LessonController alloc] initWithNibName:@"Lesson" bundle:nil];
	
	// Create our separator
	separatorCell = [[PBGSeparatorCell alloc] init];
    [separatorCell setEditable:NO];
	
	// Create a child for the camera item and add it to the source list.
	PBGTreeNode *inputs = [[PBGTreeNode alloc] initWithNodeType:SpecialFolderTreeNode
													  nodeTitle:kInputsFolderIdentifier
													andNodeIcon:nil];
	[self addNode:inputs atIndex:nil];
	[inputs release];
	
	PBGTreeNode *camera = [[PBGTreeNode alloc] initWithNodeType:CameraItemTreeNode 
													  nodeTitle:kCameraIdentifier 
													andNodeIcon:cameraIconImage];
	[self addNode:camera atIndex:nil];
	[camera release];

	NSArray *selection = [treeController selectionIndexPaths];
	[treeController removeSelectionIndexPaths:selection];
	
	PBGTreeNode *education = [[PBGTreeNode alloc] initWithNodeType:SpecialFolderTreeNode
														 nodeTitle:kEducationFolderIdentifier
													   andNodeIcon:nil];
	[self addNode:education atIndex:nil];
	[education release];
	
	// Select the camera
	NSUInteger indexes[2];
	indexes[0] = 0;
	indexes[1] = 0;
	NSIndexPath *cameraSelection = [NSIndexPath indexPathWithIndexes:indexes length:2];
	[treeController setSelectionIndexPath:cameraSelection];
	
	
	// Register to hear notifications we care about
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self 
						   selector:@selector(handleNewPicture:) 
							   name:kPictureTakenNotification 
							 object:nil];
}

#pragma mark - Notification Handling

- (void)handleNewPicture:(NSNotification *)notification
{
	
	NSString *lessonMeaning = [[notification object] valueForKey:kMeaningIdentifier];
	NSLog(@"Meaning: %@", lessonMeaning);
	
	// Search for an existing folder with our lesson name
	NSLog(@"Contents: %@", [[contents objectAtIndex:1] children]);	
	int index = [self containsExistingLessonOf:[[notification object] valueForKey:kMeaningIdentifier]];
	
	// Create our new lesson
	PBGLesson *newLesson = [[PBGLesson alloc] initWithImagePath:[[notification object] valueForKey:kFilePathIdentifier] 
														meaning:lessonMeaning];
	
	PBGTreeNode *lessonNode = [[PBGTreeNode alloc] initWithNodeType:LessonTreeNode
														  nodeTitle:lessonMeaning
														andNodeIcon:photoIconImage];
	[lessonNode setLesson:newLesson];
	
	if (index < 0) { // Create a new tree folder
		PBGTreeNode *folderNode = [[PBGTreeNode alloc] initWithNodeType:LessonFolderTreeNode
														   nodeTitle:lessonMeaning
														 andNodeIcon:photoIconImage];
				
		
		// Add our new folder to the tree and our lesson to that folder
		[self addNode:folderNode atIndex:nil];
		
		[lessonNode setNodeTitle:[lessonMeaning stringByAppendingString:@" 1"]];
		
		int foo = [[[contents objectAtIndex:1] children] indexOfObject:folderNode];
		[self addNode:lessonNode atIndex:[NSNumber numberWithInt:foo]];
		
	} else { // Add to an existing lesson
		NSMutableArray *education = (NSMutableArray *) [[contents objectAtIndex:1] children];
		int count = [[[education objectAtIndex:index] children] count];
		[lessonNode setNodeTitle:[lessonMeaning stringByAppendingFormat:@" %d", (count + 1), nil]];
		[self addNode:lessonNode atIndex:[NSNumber numberWithInt:index]];
	}


}

- (int)containsExistingLessonOf:(NSString *)thing
{
	NSMutableArray *education = (NSMutableArray *) [[contents objectAtIndex:1] children];
	
	if ([education count] == 0) {
		return -1;
	} else {
		int index = 0;
		for (index = 0; index < [education count]; index++) {
			if ([[[education objectAtIndex:index] nodeTitle] isEqualToString:thing])
				return index;
		}
	}
	return -1;
}

#pragma mark Tree Controller

- (void)selectParentFromSelection
{
	if ([[treeController selectedNodes] count] > 0)
	{
		NSTreeNode* firstSelectedNode = [[treeController selectedNodes] objectAtIndex:0];
		NSTreeNode* parentNode = [firstSelectedNode parentNode];
		if (parentNode)
		{
			// select the parent
			NSIndexPath* parentIndex = [parentNode indexPath];
			[treeController setSelectionIndexPath:parentIndex];
		}
		else
		{
			// no parent exists (we are at the top of tree), so make no selection in our outline
			NSArray* selectionIndexPaths = [treeController selectionIndexPaths];
			[treeController removeSelectionIndexPaths:selectionIndexPaths];
		}
	}
}


- (void)addNode:(PBGTreeNode *)newNode atIndex:(NSNumber *)givenIndex
{
	
	// Switch on the node type
	PBGTreeNodeType newNodeType = [newNode nodeType];
	switch(newNodeType) {
		case SpecialFolderTreeNode:
			
			[treeController insertObject:newNode atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:[contents count]]];
			
			break;
		
		case CameraItemTreeNode:
			
			NSLog(@"Loading camera.");
			NSIndexPath *ip = [treeController selectionIndexPath];
			ip = [ip indexPathByAddingIndex:[[[[treeController selectedObjects] objectAtIndex:0] children] count]];
			NSLog(@"Index: %@", ip);
			[treeController insertObject:newNode atArrangedObjectIndexPath:ip];
			
			break;
			
		case LessonFolderTreeNode:
			NSLog(@"Blah");
			
			NSUInteger findexes[2];
			findexes[0] = 1;
			findexes[1] = [[[contents objectAtIndex:1] children] count]; //However many are in education
			NSIndexPath *findex = [NSIndexPath indexPathWithIndexes:findexes length:2];
			[treeController insertObject:newNode atArrangedObjectIndexPath:findex];
			
			// Make sure the camera is still selected
			[self selectCamera];
			break;
			
		case LessonTreeNode:
			NSLog(@"Woot.");
			
			NSUInteger indexes[3];
			indexes[0] = 1;
			indexes[1] = [givenIndex intValue];
			indexes[2] = [[[[[contents objectAtIndex:1] children] objectAtIndex:[givenIndex intValue]] children] count];
			NSIndexPath *index = [NSIndexPath indexPathWithIndexes:indexes length:3];
			[treeController insertObject:newNode atArrangedObjectIndexPath:index];
			
			// Make sure the camera is still selected
			[self selectCamera];
		
			break;
			
		default:
			NSLog(@"Unknown nodeType passed to addNode:");
	}
	
}

- (void)selectCamera
{
	NSIndexPath *cameraPath = [[NSIndexPath indexPathWithIndex:0] indexPathByAddingIndex:0];
	[treeController setSelectionIndexPath:cameraPath];	
}

- (void)addFolder:(PBGTreeNode *)treeAddition
{
	// NSTreeController inserts objects using NSIndexPath, so we need to calculate this
	NSIndexPath *indexPath = nil;
	
	/* if there is no selection, we will add a new group to the end of the contents array
	if ([[treeController selectedObjects] count] == 0)
	{
		// there's no selection so add the folder to the top-level and at the end
		indexPath = [NSIndexPath indexPathWithIndex:[contents count]];
	}
	else
	{
		// get the index of the currently selected node, then add the number its children to the path -
		// this will give us an index which will allow us to add a node to the end of the currently selected node's children array.
		//
		indexPath = [treeController selectionIndexPath];
		if ([[[treeController selectedObjects] objectAtIndex:0] isLeaf])
		{
			// user is trying to add a folder on a selected child,
			// so deselect child and select its parent for addition
			[self selectParentFromSelection];
		}
		else
		{
			indexPath = [indexPath indexPathByAddingIndex:[[[[treeController selectedObjects] objectAtIndex:0] children] count]];
		}
	}
	*/
	
	if ([contents count] > 1) {
		NSUInteger indexes[2];
		indexes[0] = 1;
		indexes[1] = 0;
		indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
	
		// the user is adding a child node, tell the controller directly
	} else {
		indexPath = [NSIndexPath indexPathWithIndex:[contents count]];
	}
					 
	[treeController insertObject:treeAddition atArrangedObjectIndexPath:indexPath];
	
}


- (void)addElement:(PBGTreeNode *)treeAddition
{
	if ([[treeController selectedObjects] count] > 0)
	{
		/* we have a selection
		//if ([[[treeController selectedObjects] objectAtIndex:0] isLeaf])
		{
			// trying to add a child to a selected leaf node, so select its parent for add
			[self selectParentFromSelection];
		} */
	}
	
	// find the selection to insert our node
	NSIndexPath *indexPath;
	if ([[treeController selectedObjects] count] > 0)
	{
		// we have a selection, insert at the end of the selection
		indexPath = [treeController selectionIndexPath];
		indexPath = [indexPath indexPathByAddingIndex:[[[[treeController selectedObjects] objectAtIndex:0] children] count]];
	}
	else
	{
		// no selection, just add the child to the end of the tree
		indexPath = [NSIndexPath indexPathWithIndex:[contents count]];
	}
	
	
	// the user is adding a child node, tell the controller directly
	[treeController insertObject:treeAddition atArrangedObjectIndexPath:indexPath];
		
	// adding a child automatically becomes selected by NSOutlineView, so keep its parent selected
	//if ([treeAddition selectItsParent])
	//	[self selectParentFromSelection];
}

#pragma mark - Application Delegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}


#pragma mark - Split View Delegate



- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate + kMinOutlineViewSplit;
}

- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate - kMinOutlineViewSplit;
}


//	Keep the left split pane from resizing as the user moves the divider line.
- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame]; // get the new size of the whole splitView
	NSView *left = [[sender subviews] objectAtIndex:0];
	NSRect leftFrame = [left frame];
	NSView *right = [[sender subviews] objectAtIndex:1];
	NSRect rightFrame = [right frame];
	
	CGFloat dividerThickness = [sender dividerThickness];
	
	leftFrame.size.height = newFrame.size.height;
	
	rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
	rightFrame.size.height = newFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	
	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}

#pragma mark - KVC

- (void)setContents:(NSArray*)newContents
{
	if (contents != newContents)
	{
		[contents release];
		contents = [[NSMutableArray alloc] initWithArray:newContents];
	}
}

- (NSMutableArray *)contents
{
	return contents;
}


#pragma mark - Learning notifications

//Listen for notifications that a picture was taken

#pragma mark - NSOutlineView delegate


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
	// don't allow special group nodes (Devices and Places) to be selected
	PBGTreeNode* node = [item representedObject];
	return (![self isSpecialGroup:node]);
}


- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell* returnCell = [tableColumn dataCell];
	
	if ([[tableColumn identifier] isEqualToString:kSourcesColumnIdentifier])
	{
		// we are being asked for the cell for the single and only column
		PBGTreeNode* node = [item representedObject];
		if ([node nodeIcon] == nil && [[node nodeTitle] length] == 0)
			returnCell = separatorCell;
	}
	
	return returnCell;
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	if ([[fieldEditor string] length] == 0)
	{
		// don't allow empty node names
		return NO;
	}
	else
	{
		return YES;
	}
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BOOL result = YES;
	
	item = [item representedObject];
	if ([self isSpecialGroup:item])
	{
		result = NO; // don't allow special group nodes to be renamed
	}
	
	return result;
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[tableColumn identifier] isEqualToString:kSourcesColumnIdentifier] && [cell isKindOfClass:[PBGImageAndTextCell class]]) {
		item = [item representedObject];
		if (item) {
			[(PBGImageAndTextCell*)cell setImage:[item nodeIcon]];
		}
	}
}

#pragma mark - View swapping

- (void)removeSubview
{
	// empty selection
	NSArray *subViews = [mainView subviews];
	if ([subViews count] > 0)
	{
		[[subViews objectAtIndex:0] removeFromSuperview];
	}
	
	[mainView displayIfNeeded];	// we want the removed views to disappear right away
}


- (void)changeItemView
{
	NSArray		*selection = [treeController selectedObjects];	
	PBGTreeNode	*node = [selection objectAtIndex:0];
	//NSString	*urlStr = [node urlString];
	NSString	*name = [node nodeTitle];
	
	// If the user selected the camera view, switch to that unless we're already there.
	if(name == kCameraIdentifier && currentView != [cameraController view]) {
		[self removeSubview];
		currentView = [cameraController view];
		[mainView addSubview:[cameraController view]];
	}
	
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{	
	// ask the tree controller for the current selection
	NSArray *selection = [treeController selectedObjects];
	if ([selection count] > 1)
	{
		// multiple selection - clear the right side view
		[self removeSubview];
		currentView = nil;
	}
	else
	{
		if ([selection count] == 1)
		{
			// single selection
			[self changeItemView];
		}
		else
		{
			// there is no current selection - no view to display
			[self removeSubview];
			currentView = nil;
		}
	}
}


-(BOOL)outlineView:(NSOutlineView*)outlineView isGroupItem:(id)item
{
	if ([self isSpecialGroup:[item representedObject]])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL)isSpecialGroup:(PBGTreeNode *)groupNode
{ 
	return ([groupNode nodeIcon] == nil && ([[groupNode nodeTitle] isEqualToString:kInputsFolderIdentifier] || 
											[[groupNode nodeTitle] isEqualToString:kEducationFolderIdentifier]));
}

- (void)dealloc
{
	[contents release];
	[cameraIconImage release];
	[photoIconImage release];
	[super dealloc];	
}

@end
