NS_ASSUME_NONNULL_BEGIN

@interface SKProgressController : NSWindowController {
    NSProgressIndicator *progressBar;
    NSTextField *progressField;
}

@property (nonatomic, nullable, strong) IBOutlet NSProgressIndicator *progressBar;
@property (nonatomic, nullable, strong) IBOutlet NSTextField *progressField;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, getter=isIndeterminate) BOOL indeterminate;
@property (nonatomic) double maxValue, doubleValue;

- (void)incrementBy:(double)delta;

@end

NS_ASSUME_NONNULL_END
