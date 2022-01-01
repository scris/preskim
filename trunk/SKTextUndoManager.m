//
//  SKTextUndoManager.m
//  Skim
//
//  Created by Christiaan Hofman on 13/11/2021.
/*
This software is Copyright (c) 2021-2022
Christiaan Hofman. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in
   the documentation and/or other materials provided with the
   distribution.

- Neither the name of Christiaan Hofman nor the names of any
   contributors may be used to endorse or promote products derived
   from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "SKTextUndoManager.h"


@implementation SKTextUndoManager

- (id)initWithNextUndoManager:(NSUndoManager *)undoManager {
    self = [super init];
    if (self) {
        nextUndoManager = [undoManager retain];
    }
    return self;
}

- (void)dealloc {
    SKDESTROY(nextUndoManager);
    [super dealloc];
}

- (NSString *)redoMenuItemTitle {
    return [super canRedo] || nextUndoManager == nil ? [super redoMenuItemTitle] : [nextUndoManager redoMenuItemTitle];
}

- (NSString *)undoMenuItemTitle {
    return [super canUndo] || nextUndoManager == nil ? [super undoMenuItemTitle] : [nextUndoManager undoMenuItemTitle];
}

- (BOOL)canRedo {
    return [super canRedo] || [nextUndoManager canRedo];
}

- (BOOL)canUndo {
    return [super canUndo] || [nextUndoManager canUndo];
}

- (void)redo {
    if ([super canRedo])
        [super redo];
    else
        [nextUndoManager redo];
}

- (void)undo {
    if ([super canUndo])
        [super undo];
    else
        [nextUndoManager undo];
}

@end
