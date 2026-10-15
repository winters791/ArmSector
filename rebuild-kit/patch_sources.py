# Source patches on top of LWJGL 2.9.3 for the Apple Silicon Starsector build.
import sys, os
L = sys.argv[1]
def patch(rel, old, new):
    p = os.path.join(L, rel); s = open(p).read()
    if new in s: return
    assert s.count(old) == 1, (rel, old[:60]); open(p, 'w').write(s.replace(old, new))

# Build fixes for current toolchains (JDK 9+ javac, macOS SDKs without JavaVM.framework headers).
patch('src/java/org/lwjgl/util/generator/GeneratorVisitor.java',
'java_writer = new PrintWriter(env.getFiler().createSourceFile(Utils.getQualifiedClassName(e), env.getElementUtils().getPackageOf(e)).openWriter());',
'outputJava.getParentFile().mkdirs(); java_writer = new PrintWriter(new java.io.FileWriter(outputJava)); // JDK 9+ Filer refuses to "recreate" the template type')
patch('src/native/macosx/context.h', '#include <jawt_md.h>', '#include <JavaVM/jawt_md.h> /* compat shim in headers/ */')
os.makedirs(os.path.join(L, 'headers/JavaVM'), exist_ok=True)
open(os.path.join(L, 'headers/JavaVM/jawt_md.h'), 'w').write('''/* Compat shim: Apple's JavaVM.framework jawt_md.h is gone from modern JDKs/SDKs. */
#ifndef LWJGL_COMPAT_JAVAVM_JAWT_MD_H
#define LWJGL_COMPAT_JAVAVM_JAWT_MD_H
#include <jawt.h>
#include <jawt_md.h>
#ifdef __OBJC__
#import <AppKit/NSView.h>
typedef struct JAWT_MacOSXDrawingSurfaceInfo { NSView *cocoaViewRef; } JAWT_MacOSXDrawingSurfaceInfo;
#else
typedef struct JAWT_MacOSXDrawingSurfaceInfo { void *cocoaViewRef; } JAWT_MacOSXDrawingSurfaceInfo;
#endif
#endif
''')
# javac -h only emits @Native constants; javah used to emit this one.
open(os.path.join(L, 'headers/org_lwjgl_MacOSXSysImplementation.h'), 'w').write(
    '/* javah-style constant */\n#define org_lwjgl_MacOSXSysImplementation_JNI_VERSION 25L\n')

# Fullscreen: stay on the main screen at normal window level, hide Dock/menu bar only while active,
# so Cmd+Tab and Mission Control can bring other apps in front (default options cover all screens at a raised level).
patch('src/native/macosx/org_lwjgl_opengl_Display.m',
'''		[window_info->view enterFullScreenMode: [NSScreen mainScreen] withOptions: nil ];''',
'''		NSDictionary *fs_options = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:NO], NSFullScreenModeAllScreens,
			[NSNumber numberWithInteger:NSNormalWindowLevel], NSFullScreenModeWindowLevel,
			[NSNumber numberWithUnsignedInteger:(NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar)], NSFullScreenModeApplicationPresentationOptions,
			nil];
		[window_info->view enterFullScreenMode: [NSScreen mainScreen] withOptions: fs_options ];''')

# BOOL was passed through performSelector:withObject: as an object pointer.
# Surface density: AppKit's default for wantsBestResolutionOpenGLSurface depends on the SDK the JVM was built with
# (Retina 2x for a modern JDK), but LWJGL's Java side assumes 1x unless enableHighDPI is set -> set it both ways.
# (Also: stock code passed a BOOL through performSelector:withObject: as an object pointer.)
patch('src/native/macosx/org_lwjgl_opengl_Display.m',
'''	if (window_info->enableHighDPI) {
		// call method using runtime selector as its a 10.7+ api and allows compiling on older SDK's
		[window_info->view performSelector:NSSelectorFromString(@"setWantsBestResolutionOpenGLSurface:") withObject:YES];
	}''',
'''	[window_info->view setWantsBestResolutionOpenGLSurface:(window_info->enableHighDPI ? YES : NO)];''')

# Deprecated API no longer declared in the SDK; returns size_t (implicit int declaration is unsafe on arm64).
patch('src/native/macosx/context.m',
'''#import "context.h"''',
'''#import "context.h"

extern size_t CGDisplayBitsPerPixel(CGDirectDisplayID display);''')
print("patched")

# --- Main-thread fixes: a JVM built against a modern macOS SDK makes AppKit trap
# ("-[NSOpenGLContext setView:] must be called from the main thread") instead of tolerating it.
patch('src/native/macosx/context.h',
'''#include <JavaVM/jawt_md.h> /* compat shim in headers/ */''',
'''#include <JavaVM/jawt_md.h> /* compat shim in headers/ */

// Runs block on the AppKit main thread and waits for it.
static inline void lwjgl_sync_on_main(void (^block)(void)) {
	if ([NSThread isMainThread]) block();
	else dispatch_sync(dispatch_get_main_queue(), block);
}''')

C = 'src/native/macosx/org_lwjgl_opengl_MacOSXContextImplementation.m'
patch(C,
'''    MacOSXPeerInfo *peer_info;
} MacOSXContext;''',
'''    MacOSXPeerInfo *peer_info;
    NSSize last_update_size; // drawable size at the last render-thread update forwarded to the main thread
} MacOSXContext;''')

# Called every frame by MacOSXDisplay.update(). The view already calls -update on the main thread on every
# frame change (NSViewGlobalFrameDidChangeNotification), so from the render thread only forward real size changes.
patch(C,
'''	MacOSXContext *context_info = (MacOSXContext *)(*env)->GetDirectBufferAddress(env, context_handle);
	[context_info->context update];
	[pool release];''',
'''	MacOSXContext *context_info = (MacOSXContext *)(*env)->GetDirectBufferAddress(env, context_handle);
	if ([NSThread isMainThread]) {
		[context_info->context update];
	} else {
		NSView *view = [context_info->context view];
		NSSize size = view != nil ? [view convertRectToBacking:[view bounds]].size : NSZeroSize;
		if (!NSEqualSizes(size, context_info->last_update_size)) {
			context_info->last_update_size = size;
			NSOpenGLContext *context = context_info->context;
			lwjgl_sync_on_main(^{ [context update]; });
		}
	}
	[pool release];''')

patch(C,
'''	MacOSXContext *context_info = (MacOSXContext *)(*env)->GetDirectBufferAddress(env, context_handle);
	[context_info->context clearDrawable];
	[pool release];''',
'''	MacOSXContext *context_info = (MacOSXContext *)(*env)->GetDirectBufferAddress(env, context_handle);
	NSOpenGLContext *context = context_info->context;
	lwjgl_sync_on_main(^{ [context clearDrawable]; });
	context_info->last_update_size = NSZeroSize;
	[pool release];''')

patch(C,
'''		[context_info->context setView: peer_info->window_info->view];''',
'''		NSOpenGLContext *context = context_info->context;
		NSView *view = peer_info->window_info->view;
		lwjgl_sync_on_main(^{ [context setView: view]; });
		context_info->last_update_size = NSZeroSize;''')

patch(C,
'''	[context_info->context clearDrawable];
	
	if (context_info->peer_info->isWindowed) {''',
'''	NSOpenGLContext *destroyed_context = context_info->context;
	lwjgl_sync_on_main(^{ [destroyed_context clearDrawable]; });
	
	if (context_info->peer_info->isWindowed) {''')

D = 'src/native/macosx/org_lwjgl_opengl_Display.m'
patch(D,
'''	MacOSXWindowInfo *window_info = (MacOSXWindowInfo *)(*env)->GetDirectBufferAddress(env, window_handle);
	NSUInteger style_mask = [window_info->window styleMask];''',
'''	MacOSXWindowInfo *window_info = (MacOSXWindowInfo *)(*env)->GetDirectBufferAddress(env, window_handle);
	lwjgl_sync_on_main(^{
	NSUInteger style_mask = [window_info->window styleMask];''')
patch(D,
'''			[window_info->window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
		}
	}
}''',
'''			[window_info->window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
		}
	}
	});
}''')
print("main-thread patches applied")
