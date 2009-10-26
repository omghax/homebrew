require 'formula'

class Screen <Formula
  url 'http://ftp.gnu.org/gnu/screen/screen-4.0.3.tar.gz'
  homepage 'http://www.gnu.org/software/screen/'
  md5 '8506fd205028a96c741e4037de6e3c42'
  
  def patches
    {:p0 => DATA}
  end
  
  # GNU screen formula based on the screen @4.0.3_1 port in MacPorts.  This
  # version fixes a problem with TextMate's "mate" command, and other
  # command-line executables.
  # 
  # http://wiki.macromates.com/Troubleshooting/MateFailsWithScreen
  def install
    # Use existing system ncurses library.
    ENV["LIBS"] = "-lncurses"
    
    system "./configure", "--prefix=#{prefix}",
                          "--mandir=#{prefix}/share/man",
                          "--infodir=#{prefix}/share/info",
                          "--enable-locale",
                          "--enable-telnet",
                          "--enable-colors256",
                          "--enable-rxvt_osc"
    system "make install"
  end
end

__END__
--- ansi.c.orig	Mon Sep  8 16:24:44 2003
+++ ansi.c
@@ -559,7 +559,7 @@ register int len;
 	    {
 	    case '0': case '1': case '2': case '3': case '4':
 	    case '5': case '6': case '7': case '8': case '9':
-	      if (curr->w_NumArgs < MAXARGS)
+	      if (curr->w_NumArgs >= 0 && curr->w_NumArgs < MAXARGS)
 		{
 		  if (curr->w_args[curr->w_NumArgs] < 100000000)
 		    curr->w_args[curr->w_NumArgs] =
--- osdef.h.in	Tue Oct 29 23:22:33 2002
+++ osdef.h.in.dports	Tue Oct 29 23:37:25 2002
@@ -87,16 +87,16 @@
 extern int   setresuid __P((int, int, int));
 extern int   setresgid __P((int, int, int));
 # else
-extern int   setreuid __P((int, int));
-extern int   setregid __P((int, int));
+extern int   setreuid __P((uid_t, uid_t));
+extern int   setregid __P((gid_t, gid_t));
 # endif
 #endif
 #ifdef HAVE_SETEUID
-extern int   seteuid __P((int));
-extern int   setegid __P((int));
+extern int   seteuid __P((uid_t));
+extern int   setegid __P((gid_t));
 #endif
 
-extern char *crypt __P((char *, char *));
+extern char *crypt __P((const char *, const char *));
 extern int   putenv __P((char *));
 
 extern int   tgetent __P((char *, char *));
@@ -115,26 +115,26 @@
 
 extern int   kill __P((int, int));
 
-extern int   getpid __P((void));
-extern int   getuid __P((void)); 
-extern int   geteuid __P((void));
-extern int   getgid __P((void)); 
-extern int   getegid __P((void));
+extern pid_t   getpid __P((void));
+extern uid_t   getuid __P((void)); 
+extern uid_t   geteuid __P((void));
+extern gid_t   getgid __P((void)); 
+extern gid_t   getegid __P((void));
 struct passwd;	/* for getpwuid __P */
 extern struct passwd *getpwuid __P((int));
 extern struct passwd *getpwnam __P((char *));
 extern int   isatty __P((int)); 
-extern int   chown __P((char *, int, int)); 
+extern int   chown __P((const char *, uid_t, gid_t)); 
 extern int   rename __P((char *, char *));
 
 extern int   gethostname __P((char *, int));
-extern int   lseek __P((int, int, int));
+extern off_t   lseek __P((int, off_t, int));
 extern void  exit __P((int));
 extern char *getwd __P((char *));
 extern char *getenv __P((char *));
 extern time_t time __P((time_t *));
 
-extern char *getpass __P((char *));
+extern char *getpass __P((const char *));
 extern char *getlogin __P((void));
 extern char *ttyname __P((int));
 
@@ -148,7 +148,7 @@
 extern void  free __P((char *));
 
 #ifdef NAMEDPIPE
-extern int   mknod __P((char *, int, int));
+extern int   mknod __P((const char *, mode_t, dev_t));
 #else
 struct sockaddr;	/* for connect __P */
 extern int   socket __P((int, int, int));
--- ./pty.c.orig	2003-09-08 16:26:18.000000000 +0200
+++ ./pty.c	2007-10-28 16:27:56.000000000 +0100
@@ -34,7 +34,7 @@
 #endif
 
 /* for solaris 2.1, Unixware (SVR4.2) and possibly others */
-#ifdef HAVE_SVR4_PTYS
+#if defined(HAVE_SVR4_PTYS) && !defined(__APPLE__)
 # include <sys/stropts.h>
 #endif
 
--- resize.c.orig	Mon Sep  8 16:26:31 2003
+++ resize.c
@@ -682,6 +682,17 @@ int wi, he, hi;
   if (wi == 0)
     he = hi = 0;
 
+  if (wi > 1000)
+    {
+      Msg(0, "Window width too large, truncated");
+      wi = 1000;
+    }
+  if (he > 1000)
+    {
+      Msg(0, "Window height too large, truncated");
+      he = 1000;
+    }
+
   if (p->w_width == wi && p->w_height == he && p->w_histheight == hi)
     {
       debug("ChangeWindowSize: No change.\n");
--- comm.c.orig	2003-09-08 14:25:08.000000000 +0000
+++ comm.c	2006-07-07 02:39:24.000000000 +0000
@@ -309,6 +309,7 @@ struct comm comms[RC_LAST + 1] =
   { "vbellwait",	ARGS_1 },
   { "verbose",		ARGS_01 },
   { "version",		ARGS_0 },
+  { "vert_split",		NEED_DISPLAY|ARGS_0 },
   { "wall",		NEED_DISPLAY|ARGS_1},
   { "width",		ARGS_0123 },
   { "windowlist",	NEED_DISPLAY|ARGS_012 },
--- display.c.orig	2003-12-05 13:45:41.000000000 +0000
+++ display.c	2006-07-07 02:39:26.000000000 +0000
@@ -476,65 +476,306 @@ struct canvas *cv;
   free(cv);
 }
 
+struct canvas *
+get_new_canvas(target)
+struct canvas *target;
+{   /** Allocate a new canvas, and assign it characteristics
+    equal to those of target. */
+    struct canvas *cv;
+
+    if ((cv = (struct canvas *) calloc(1, sizeof *cv)) == 0)
+        return NULL;
+
+    cv -> c_xs               = target -> c_xs;
+    cv -> c_xe               = target -> c_xe;
+    cv -> c_ys               = target -> c_ys;
+    cv -> c_ye               = target -> c_ye;
+    cv -> c_xoff             = target -> c_xoff;
+    cv -> c_yoff             = target -> c_yoff;
+    cv -> c_display          = target -> c_display;
+    cv -> c_vplist           = 0;
+    cv -> c_captev.type      = EV_TIMEOUT;
+    cv -> c_captev.data      = (char *) cv;
+    cv -> c_captev.handler   = cv_winid_fn;
+
+    cv -> c_blank.l_cvlist   = cv;
+    cv -> c_blank.l_width    = cv->c_xe - cv->c_xs + 1;
+    cv -> c_blank.l_height   = cv->c_ye - cv->c_ys + 1;
+    cv -> c_blank.l_x        = cv->c_blank.l_y = 0;
+    cv -> c_blank.l_layfn    = &BlankLf;
+    cv -> c_blank.l_data     = 0;
+    cv -> c_blank.l_next     = 0;
+    cv -> c_blank.l_bottom   = &cv->c_blank;
+    cv -> c_blank.l_blocking = 0;
+    cv -> c_layer            = &cv->c_blank;
+    cv -> c_lnext            = 0;
+
+    cv -> c_left  = target -> c_left;
+    cv -> c_right = target -> c_right;
+    cv -> c_above = target -> c_above;
+    cv -> c_below = target -> c_below;
+
+    return cv;
+}
+
 int
-AddCanvas()
-{
-  int hh, h, i, j;
-  struct canvas *cv, **cvpp;
+share_limits( type, cv0, cv1)
+int type;       /* HORIZONTAL or VERTICAL */
+struct canvas *cv0;  /* canvas to compare against. */
+struct canvas *cv1;  /* canvas to compare against. */
+{   /** Return non-zero if the two canvasses share limits. 
+    (ie, their horizontal or veritcal boundaries are the same)
+    */
+    switch (type) {
+    case HORIZONTAL:
+        return cv0 -> c_xs == cv1 -> c_xs && cv0->c_xe == cv1 -> c_xe;
+    case VERTICAL:
+        return cv0 -> c_ys == cv1 -> c_ys && cv0->c_ye == cv1 -> c_ye;
+    }
+    ASSERT(0);
+    return 0;
+}
 
-  for (cv = D_cvlist, j = 0; cv; cv = cv->c_next)
-    j++;
-  j++;	/* new canvas */
-  h = D_height - (D_has_hstatus == HSTATUS_LASTLINE);
-  if (h / j <= 1)
-    return -1;
+int
+compute_region(type, a, focus, list)
+int type;  /* 0 - horizontal, 1 - vertical */
+struct screen_region *a;  /* Return value. */
+struct canvas *focus;  /* Canvas to compute around. */
+struct canvas *list;   /* List of all canvasses. */
+{   /** Find the start and end of the screen region.*/
+    /*
+    I'm using the term 'region' here differently
+    than elsewhere.  Elsewhere, 'region' is synonymous
+    with 'canvas', but I am using it to denote
+    a collection of related canvasses.
 
-  for (cv = D_cvlist; cv; cv = cv->c_next)
-    if (cv == D_forecv)
+    Suppose the screen currently looks
+    like this:
+    ---------------------------
+    |  0   |   1    |    2    |
+    ---------------------------
+    |  3   |   4    |    5    |
+    ---------------------------
+    |          6              |
+    ---------------------------
+    |   7  |   8    |    9    |
+    ---------------------------
+    Where there are 10 entries in D_cvlist.
+    Canvasses 0,1,2 are in the same region, as
+    are cavasses 1 and 4.  We need to be careful not to
+    lump 1 and 4 together w/8.  The
+    type of the region containing 0,1,2 is
+    VERTICAL, since each canvas is created
+    via a vertical split.
+
+    Throughout, I'm assuming that canvasses
+    are created so that any region will
+    be contiguous in D_cvlist.
+
+    Note: this was written before the screen 
+    orientation members (c_left, c_above, c_below,
+    c_right) were added to the struct canvas.
+    Might want to rewrite this to use those.
+
+    Written by Bill Pursell, 23/12/2005
+    */
+
+    struct canvas *cv;  /* Entry in list. */
+    int seen_focus;     /* Flag used when walking the list. */
+
+    seen_focus = 0;
+    a->count = 0;
+    a->type  = type;
+
+    if (type == HORIZONTAL) {
+        a->xs = focus -> c_xs;
+        a->xe = focus -> c_xe;
+        a->ys = -1;
+    }
+    if (type == VERTICAL) {
+        a->ys = focus -> c_ys;
+        a->ye = focus -> c_ye;
+        a->xs = -1;
+    }
+    /* Count the canvasses in the same region as the
+    canvas with the focus, and find the limits of the region. */
+    for (cv = list; cv; cv = cv->c_next) {
+        if (cv == focus)
+            seen_focus = 1;
+        if (share_limits( type, cv, focus)) {
+            debug2("cv = %x  %s\n", cv, (cv == focus)? "FORE":"");
+            debug2("x range: %d - %d\n", cv->c_xs, cv->c_xe);
+            debug2("y range: %d - %d\n", cv->c_ys, cv->c_ye);
+            switch (type) {
+            case HORIZONTAL  : 
+                if (a->ys == -1) {
+                    a->ys = cv -> c_ys; 
+                    a->start = cv;
+                }
+                a->ye = cv -> c_ye;
       break;
-  ASSERT(cv);
-  cvpp = &cv->c_next;
+            case VERTICAL:
+                if (a->xs == -1) {
+                    a->xs = cv -> c_xs; 
+                    a->start = cv;
+                }
+                a->xe = cv -> c_xe;
+                break;
+            }
 
-  if ((cv = (struct canvas *)calloc(1, sizeof *cv)) == 0)
-    return -1;
+            a->end = cv;
+            a->count++;
+        }
+        if (!share_limits(type, cv, focus) || cv -> c_next == NULL) {
+            if (seen_focus) {
+                debug2("x range of Region: %d-%d\n", a->xs, a->xe);
+                debug2("y range of Region: %d-%d\n", a->ys, a->ye);
+                break;
+            }
+            else {
+                switch(type) {
+                case HORIZONTAL: a->ys = -1; break;
+                case VERTICAL  : a->xs = -1; break;
+                }
+                a->count = 0;
+            }
+        }
+    }
 
-  cv->c_xs      = 0;
-  cv->c_xe      = D_width - 1;
-  cv->c_ys      = 0;
-  cv->c_ye      = D_height - 1;
-  cv->c_xoff    = 0;
-  cv->c_yoff    = 0;
-  cv->c_display = display;
-  cv->c_vplist  = 0;
-  cv->c_captev.type = EV_TIMEOUT;
-  cv->c_captev.data = (char *)cv;
-  cv->c_captev.handler = cv_winid_fn;
+    switch (type) {
+    case HORIZONTAL: 
+        a->expanse  = a->ye - a->ys + 1;  
+        ASSERT(a->expanse <=  D_height - (D_has_hstatus == HSTATUS_LASTLINE));
+        break;
+    case VERTICAL:   
+        a->expanse  = a->xe - a->xs + 1;  
+        ASSERT(a->expanse <=  D_width);
+        break;
+    }
+    ASSERT(seen_focus);
+}
 
-  cv->c_blank.l_cvlist = cv;
-  cv->c_blank.l_width = cv->c_xe - cv->c_xs + 1;
-  cv->c_blank.l_height = cv->c_ye - cv->c_ys + 1;
-  cv->c_blank.l_x = cv->c_blank.l_y = 0;
-  cv->c_blank.l_layfn = &BlankLf;
-  cv->c_blank.l_data = 0;
-  cv->c_blank.l_next = 0;
-  cv->c_blank.l_bottom = &cv->c_blank;
-  cv->c_blank.l_blocking = 0;
-  cv->c_layer = &cv->c_blank;
-  cv->c_lnext = 0;
+void
+reset_region_types(region, type)
+struct screen_region *region;
+int type;
+{   /** Set c_type of all the canvasses in the region to type. */
 
-  cv->c_next    = *cvpp;
-  *cvpp = cv;
+    struct canvas *cv;
 
-  i = 0;
-  for (cv = D_cvlist; cv; cv = cv->c_next)
-    {
-      hh = h / j-- - 1;
-      cv->c_ys = i;
-      cv->c_ye = i + hh - 1;
-      cv->c_yoff = i;
-      i += hh + 1;
-      h -= hh + 1;
+    for (cv = region->start; cv != region->end->c_next; cv = cv->c_next) {
+        #ifdef DEBUG
+        switch(type) {
+        case HORIZONTAL: 
+            ASSERT (cv->c_xs == region -> xs && cv->c_xe == region -> xe);
+            break;
+        case VERTICAL:
+            ASSERT (cv->c_ys == region -> ys && cv->c_ye == region -> ye);
+            break;
+        default:
+            ASSERT(0);
+    }
+        #endif
+        cv -> c_type = type;
     }
+}
+
+void
+debug_print_canvas(cv)
+struct canvas *cv;
+{   /** Print cv to the debug file. */
+#ifdef DEBUG
+    debug2("%x %s\n", cv, (cv == D_forecv)?"  HAS FOCUS":"");
+    debug2("    above: %x    below: %x\n", cv->c_above, cv->c_below);
+    debug2("    left: %x     right: %x\n", cv->c_left,  cv->c_right);
+    debug3("    x range: %2d-%2d, xoff = %d\n", 
+        cv->c_xs, cv->c_xe, cv->c_xoff);
+    debug3("    y range: %2d-%2d yoff = %d\n", 
+        cv->c_ys, cv->c_ye, cv->c_yoff);
+    debug2("    next: %x   type: %d\n", cv->c_next, cv->c_type);
+#endif
+}
+
+void
+debug_print_all_canvasses(header)
+char *header;
+{   /** Print the dimensions of all the canvasses
+    in the current display to the debug file.  Precede
+    with a line containing the header message. */
+    #ifdef DEBUG
+    struct canvas *cv;
+    char message[BUFSIZ];
+
+    sprintf(message,  "%10s %5d: ",__FILE__ , __LINE__);
+    strcat (message, header);
+    fprintf(dfp, message);
+    fflush(dfp);
+    for (cv = D_cvlist; cv; cv = cv->c_next) {
+        debug_print_canvas(cv);
+    }
+    #endif
+    return;
+}
+
+set_internal_orientation(region)
+struct screen_region *region;
+{   /** Set the orientation for canvasses inside the region. */
+
+    struct canvas *cv;
+
+    for (cv = region -> start; cv != region -> end; cv = cv->c_next) {
+        ASSERT (cv -> c_type == region -> type);
+        switch (region->type) {
+        case VERTICAL:
+            cv -> c_right           = cv -> c_next;
+            cv -> c_next -> c_left  = cv;
+            break;
+        case HORIZONTAL:
+            cv -> c_below           = cv -> c_next;
+            cv -> c_next -> c_above = cv;
+            break;
+        }
+    }
+}
+
+
+int
+AddCanvas(type)
+int type;  /* Horizontal or Vertical. */
+{   /** Add a new canvas, via a split. */
+
+    struct canvas  *cv;        /* Index into D_cvlist. */
+    struct screen_region  vr;  /* Canvasses in the same row/column as the 
+                                  canvas with the focus.   */
+
+    compute_region(type, &vr, D_forecv, D_cvlist);
+
+    /* Return if the region isn't big enough to split. */
+    if (vr.expanse / vr.count <= 1)
+        return -1; 
+
+    /* Allocate a new canvas. */
+    if ( (cv = get_new_canvas(D_forecv)) == NULL)
+        return -1;
+
+    /* Set the type. */
+    cv -> c_type = D_forecv -> c_type = type;
+
+    /* Increment the canvas count to account for the one we will add. */
+    vr.count++;
+
+    debug_print_all_canvasses("AddCanvas start.\n");
+
+    /* Insert the new canvas after the current foreground. */
+    cv -> c_next = D_forecv->c_next;
+    D_forecv -> c_next = cv;
+    if (vr.end == D_forecv)
+        vr.end = cv;
+
+    set_internal_orientation(&vr);
+    equalize_canvas_dimensions(&vr);
+
+    debug_print_all_canvasses("AddCanvas end.\n");
 
   RethinkDisplayViewports();
   ResizeLayersToCanvases();
@@ -542,67 +783,595 @@ AddCanvas()
 }
 
 void
-RemCanvas()
+get_endpoints(cv, start, end, off)
+struct canvas *cv;
+int **start;
+int **end;
+int **off;
+{   /** Set *start, *end, and *off appropriate with cv->c_type. */
+    switch (cv->c_type) {
+    case HORIZONTAL:
+        if (start) *start = &cv -> c_ys;
+        if (end)   *end   = &cv -> c_ye;
+        if (off)   *off   = &cv -> c_yoff;
+        break;
+    case VERTICAL:
+        if (start) *start = &cv -> c_xs;
+        if (end)   *end   = &cv -> c_xe;
+        if (off)   *off   = &cv -> c_xoff;
+        break;
+    default: ASSERT(0);
+    }
+}
+
+#define MIN_HEIGHT 1
+#define MIN_WIDTH 5
+
+int
+adjust_canvas_dimensions(vr, target, amount)
+struct screen_region *vr;
+struct canvas *target;
+int amount;
+{   /** Modify the size of target by amount. */
+    
+    /* Other canvasses in the region will gain or lose
+    space to accomodate the change.  Return
+    the number of rows/columns by which the size 
+    of target is succesfully enlarged. (if amount <= 0,
+    return 0) */
+
+    struct canvas *this;    /* for walking the list. */
+    struct canvas *prev;    /* for walking the list backwards. */
+    int adjusted;           /* Amount already re-allocated. */
+    int *start, *end, *off; /* c->c_{x,y}s, c->c_{x,y}e, and c->c_{x,y}off */
+    int minimum, space;
+
+    debug1("adjust: amount = %d\n", amount);
+    debug_print_all_canvasses("ADJUST \n");
+
+    ASSERT(vr->count > 1);
+
+    if (amount == 0)
+        return 0;
+
+    switch(vr->type) {
+    case HORIZONTAL:  minimum = MIN_HEIGHT; space = 2; break;
+    case VERTICAL:    minimum = MIN_WIDTH; space = 1; break;
+    default: ASSERT(0);
+    }
+
+    if (amount < 0) {
+        debug_print_all_canvasses("PREADJUST\n");
+
+        get_endpoints(target, &start, &end, &off);
+        if (target == vr -> start) {
+            *end += amount;
+
+            if (*end < *start + minimum)
+                *end = *start + minimum;
+
+            get_endpoints(target->c_next, &start, 0, &off);
+            *start = *off = *end + space;
+
+        debug_print_all_canvasses("POSTADJUST\n\n");
+        }
+        else {
+            for (prev = vr->start; prev->c_next != target; prev = prev->c_next)
+                ;
+            ASSERT(prev && prev -> c_next == target);
+
+            *start -= amount;
+            if (*start > *end - minimum)
+                *start = *end - minimum;
+            get_endpoints(prev, 0, &end, 0);
+            *end = *start - space;
+        }
+        return 0;
+    }
+
+    ASSERT (amount > 0);
+
+    /* Reallocate space from canvasses below target. */
+    this = vr -> end;
+    adjusted = 0;
+    while ( adjusted < amount) {
+        int this_amount;   /* amount this canvas can yield. */
+        struct canvas *cv; /* For walking lists. */
+
+        if (this == target)
+            break;
+
+        get_endpoints(this, &start, &end, 0);
+        switch (vr->type) {
+        case HORIZONTAL: this_amount = *end - *start - MIN_HEIGHT; break;
+        case VERTICAL:   this_amount = *end - *start - MIN_WIDTH;  break;
+        default: ASSERT(0);
+        }
+
+        if (this_amount > amount - adjusted)
+            this_amount = amount - adjusted;
+
+        debug("target:\n");
+        debug_print_canvas(target);
+
+        debug("this:\n");
+        debug_print_canvas(this);
+
+        /* Move all canvasses between target and this by this_amount. */
+        for (cv = target; cv != this; cv = cv -> c_next) {
+            debug1("this_amount = %d\n", this_amount);
+            debug_print_canvas(cv);
+
+            get_endpoints(cv, &start, &end, 0);
+            *end += this_amount;
+            get_endpoints(cv->c_next, &start, &end, &off);
+            *start += this_amount;
+            *off = *start;
+        }
+        adjusted += this_amount;
+        debug1("adjusted: %d\n", adjusted);
+
+        debug("target:\n");
+        debug_print_canvas(target);
+
+        debug("this:\n");
+        debug_print_canvas(this);
+
+
+        /* Get the previous canvas.  TODO: include back pointers
+        in struct canvas(?). */
+        for (prev = vr->start; prev->c_next != this; prev = prev->c_next)
+            ASSERT(prev);
+        this = prev;
+    }
+    debug1("adjusted = %d\n", adjusted);
+    if (adjusted == amount || target == vr->start)
+        return adjusted;
+
+    /* Re-allocate space from canvasses above target. */
+    ASSERT(this == target);
+    for (prev = vr->start; prev->c_next != this; prev = prev->c_next)
+        ASSERT(prev);
+    this = prev;
+
+    while (adjusted < amount) {
+        int this_amount;   /* amount this canvas can yield. */
+        struct canvas *cv; /* For walking lists. */
+
+        get_endpoints(this, &start, &end, 0);
+        switch (vr->type) {
+        case HORIZONTAL: this_amount = *end - *start - MIN_HEIGHT; break;
+        case VERTICAL:   this_amount = *end - *start - MIN_WIDTH;  break;
+        default: ASSERT(0);
+        }
+
+        if (this_amount > amount - adjusted)
+            this_amount = amount - adjusted;
+
+        /* Move all canvasses between this and target by this_amount. */
+        for (cv = this; cv != target; cv = cv -> c_next) {
+            ASSERT(cv);
+            debug1("this_amount = %d\n", this_amount);
+            debug_print_canvas(cv);
+            debug("NEXT:\n");
+            debug_print_canvas(cv->c_next);
+
+            debug("getend:\n");
+            get_endpoints(cv, &start, &end, 0);
+            ASSERT(end && start );
+            ASSERT(start);
+            ASSERT(*end >= this_amount);
+            *end -= this_amount;
+            ASSERT(*end > *start);
+
+            debug("getend:\n");
+            ASSERT(cv->c_next);
+            get_endpoints(cv->c_next, &start, &end, &off);
+            ASSERT(start && off);
+            ASSERT(*start >= this_amount);
+            ASSERT(*start == *off);
+            *start -= this_amount;
+            *off = *start;
+
+            debug("adjusted\n");
+            debug_print_canvas(cv);
+            debug("NEXT:\n");
+            debug_print_canvas(cv->c_next);
+            debug("\n");
+        }
+        adjusted += this_amount;
+
+        if (this == vr->start)
+            break;
+
+        for (prev = vr->start; prev->c_next != this; prev = prev->c_next)
+            ASSERT(prev);
+        this = prev;
+    }
+    debug1("returning: %d\n", adjusted);
+    return adjusted;
+}
+
+void
+equalize_canvas_dimensions(vr)
+struct screen_region *vr;
+{   /** Reset the size of each canvas in the region. */
+
+    struct canvas *cv;  /* for walking the list. */
+    int this_size; /* new size of cv */
+    int this_start;  /* Start coordinate for current canvas. */
+
+    debug("equalize\n");
+
+    debug2("vr start = %#x, vr end = %#x\n", vr->start, vr->end);
+
+    switch(vr->type) {
+    case VERTICAL:   this_start = vr->xs; break;
+    case HORIZONTAL: this_start = vr->ys; break;
+    }
+
+    for (cv = vr->start ; ; cv = cv->c_next) {
+        ASSERT(cv);
+
+        /* For the horizontal split, leave space for a status line. */
+        this_size = vr->expanse / vr->count - (vr->type == HORIZONTAL);
+
+        /* Give any additional available rows/columns to the foreground. */
+        if (cv == D_forecv)
+            this_size += vr->expanse % vr->count;
+
+        debug_print_canvas(cv);
+        debug2("cv type = %d, vr type = %d\n", cv->c_type, vr->type);
+        ASSERT(cv -> c_type == vr->type);
+
+        switch(vr->type) {
+        case VERTICAL:
+            cv -> c_xs = cv -> c_xoff = this_start;
+            cv -> c_xe = this_start + this_size - 1;
+            this_start += this_size;
+            break;
+        case HORIZONTAL:
+            if (cv == vr->end && cv->c_ye == D_height-1-
+                (D_has_hstatus == HSTATUS_LASTLINE))
+                this_size += 1;  /* Don't make space for status line 
+                    in the bottom region (it already has one). */
+
+            cv -> c_ys = cv -> c_yoff = this_start;
+            cv -> c_ye = this_start + this_size - 1;
+            this_start += this_size + 1;  /* add one for status line. */
+            break;
+        }
+        if (cv == vr->end)
+            break;
+    }
+}
+
+void
+remove_canvas_from_list(list, cv)
+struct canvas **list;
+struct canvas *cv;
+{   /** Prune cv from the list.  Does not free cv.*/
+
+    struct canvas *pred;  /* Predecssor of cv in list. */
+
+    if (cv == *list ) {
+        *list = cv -> c_next;
+    }
+    else {
+        /* Find the predecessor of cv. */
+        for (pred = *list; pred->c_next != cv; pred = pred->c_next)
+            ASSERT(pred);
+
+        pred -> c_next = cv -> c_next;
+    }
+}
+
+void
+redirect_pointers(list, old, new)
+struct canvas *list;
+struct canvas *old;
+struct canvas *new;
+{  /** For each canvas in the list, change any
+    of its screen orientation pointers from old to new. 
+    Canvasses are not allowed to be self-referential,
+    so set such pointers to NULL.
+    */
+    struct canvas *cv;
+    for (cv=list; cv; cv = cv->c_next) {
+        if (cv -> c_left == old)
+            cv -> c_left = (cv==new)?NULL:new;
+        if (cv -> c_above == old)
+            cv -> c_above = (cv==new)?NULL:new;
+        if (cv -> c_right == old)
+            cv -> c_right = (cv==new)?NULL:new;
+        if (cv -> c_below == old)
+            cv -> c_below = (cv==new)?NULL:new;
+    }
+}
+
+struct canvas *
+squeeze(list, target, direction, distance)
+struct canvas *list;    /* List of canvasses to resize. */
+struct canvas *target;  /* Canvas in the list being removed. */
+enum directions direction;          
+int  distance;  /* Amount to squeeze. */
+{   /** Resize canvasses in the list so that target 
+    is shrunk by distance and other canvasses are grown in the 
+    specified direction.  If distance is 0, target
+    is destroyed, and the value returned is
+    the earliest canvas in the list that is grown.
+
+    If distance > 0, the value returned is an int,
+    giving the amount actually sqeezed.  (This needs
+    re-writing!)
+    (This becomes the new region head for the region
+    orphaned by target.)
+
+    TODO: this currently only implements distance == 0;
+    */
+
+    struct canvas *ret;  /* The return value.*/
+    struct canvas *cv;   /* For walking the list.*/
+
+    ret = NULL;
+
+    if (distance == 0) {
+        for (cv = list; cv; cv = cv->c_next) {
+            int *cv_coord, *cv_off, targ_coord; 
+            struct canvas **cv_orient, *targ_orient;
+
+            switch (direction) {
+            case RIGHT:
+                cv_orient   = &cv->c_right;
+                cv_coord    = &cv->c_xe;
+                cv_off      = 0;
+                targ_coord  = target->c_xe;
+                targ_orient = target->c_right;
+                break;
+            case LEFT:
+                cv_orient   = &cv->c_left;
+                cv_coord    = &cv->c_xs;
+                cv_off      = &cv->c_xoff;
+                targ_coord  = target->c_xs;
+                targ_orient = target->c_left;
+                break;
+            case UP:
+                cv_orient   = &cv->c_above;
+                cv_coord    = &cv->c_ys;
+                cv_off      = &cv->c_yoff;
+                targ_coord  = target->c_ys;
+                targ_orient = target->c_above;
+                break;
+            case DOWN:
+                cv_orient   = &cv->c_below;
+                cv_coord    = &cv->c_ye;
+                cv_off      = 0;
+                targ_coord  = target->c_ye;
+                targ_orient = target->c_below;
+                break;
+            }
+            if (*cv_orient == target) {
+                *cv_coord = targ_coord;
+                if(cv_off)
+                    *cv_off = targ_coord;
+                *cv_orient = targ_orient;
+                ret = (ret) ? ret : cv;
+            }
+        }
+    }
+    else {
+        ASSERT(distance > 0);
+        switch (direction) {
+        /* adjust target first. */
+        case RIGHT:
+            if (target->c_xe - target->c_xs + distance < MIN_WIDTH)
+                distance = target->c_xe - target->c_xs - MIN_WIDTH;
+            target->c_xs += distance;
+            target->c_xoff = target -> c_xs;
+            break;
+        case LEFT:
+            if (target->c_xe - target->c_xs + distance < MIN_WIDTH)
+                distance = target->c_xe - target->c_xs - MIN_WIDTH;
+            target->c_xe -= distance;
+            break;
+        case UP:
+            if (target->c_ye - target->c_ys + distance < MIN_HEIGHT)
+                distance = target->c_ye - target->c_ys - MIN_HEIGHT;
+            target->c_ye -= distance;
+            break;
+        case DOWN:
+            if (target->c_ye - target->c_ys + distance < MIN_HEIGHT)
+                distance = target->c_ye - target->c_ys - MIN_HEIGHT;
+            target->c_ys += distance;
+            target->c_yoff = target -> c_ys;
+            break;
+        }
+        for (cv = list; cv; cv = cv->c_next) {
+            int *cv_coord, *cv_off, new_coord; 
+            struct canvas **cv_orient;
+
+            debug("SQUEEZE\n");
+            debug_print_canvas(cv);
+
+            if (cv == target)
+                continue;
+
+            switch (direction) {
+            case RIGHT:
+                cv_orient   = &cv->c_right;
+                cv_coord    = &cv->c_xe;
+                cv_off      = 0;
+                new_coord   = cv->c_xe + distance;
+                break;
+            case LEFT:
+                cv_orient   = &cv->c_left;
+                cv_coord    = &cv->c_xs;
+                cv_off      = &cv->c_xoff;
+                new_coord   = cv->c_xs - distance;
+                break;
+            case UP:
+                cv_orient   = &cv->c_above;
+                cv_coord    = &cv->c_ys;
+                cv_off      = &cv->c_yoff;
+                new_coord   = cv->c_ys - distance;
+                break;
+            case DOWN:
+                cv_orient   = &cv->c_below;
+                cv_coord    = &cv->c_ye;
+                cv_off      = 0;
+                new_coord   = cv->c_ye + distance;
+                break;
+            }
+            if (*cv_orient == target) {
+                *cv_coord = new_coord;
+                if(cv_off)
+                    *cv_off = new_coord;
+            }
+        }
+        ret = (struct canvas *) distance;
+    }
+
+
+    debug2("squeeze: target = %#x, ret = %#x\n", target, ret);
+    return ret;
+}
+
+
+struct canvas *
+grow_surrounding_regions(list, fore, amount)
+    struct canvas *list;
+    struct canvas *fore;
+    int amount;
 {
-  int hh, h, i, j;
-  struct canvas *cv, **cvpp;
-  int did = 0;
+    /* Grow all the regions in the list that border
+    fore appropriately.  */
+    struct canvas *cv;        /* For walking the list. */
+    struct canvas *new_fore;  /* Replacement for fore. */
 
-  h = D_height - (D_has_hstatus == HSTATUS_LASTLINE);
-  for (cv = D_cvlist, j = 0; cv; cv = cv->c_next)
-    j++;
-  if (j == 1)
-    return;
-  i = 0;
-  j--;
-  for (cvpp = &D_cvlist; (cv = *cvpp); cvpp = &cv->c_next)
-    {
-      if (cv == D_forecv && !did)
-	{
-	  *cvpp = cv->c_next;
-	  FreeCanvas(cv);
-	  cv = *cvpp;
-	  D_forecv = cv ? cv : D_cvlist;
-	  D_fore = Layer2Window(D_forecv->c_layer);
-	  flayer = D_forecv->c_layer;
-	  if (cv == 0)
+    debug("grow_surrounding_regions\n");
+
+    new_fore = NULL;
+    if (amount == 0) {
+        if (fore != list) {
+            /* Grow the regions from above (the left). */
+            switch (fore -> c_type) {
+            case HORIZONTAL: 
+                if ( !(new_fore = squeeze(list, fore, DOWN, 0))) 
+                    new_fore = squeeze(list, fore, RIGHT, 0);
+                break;
+            case VERTICAL:   
+                if ( !(new_fore = squeeze(list, fore, RIGHT, 0)))
+                    new_fore = squeeze(list, fore, DOWN, 0);
 	    break;
-	  did = 1;
 	}
-      hh = h / j-- - 1;
-      if (!captionalways && i == 0 && j == 0)
-	hh++;
-      cv->c_ys = i;
-      cv->c_ye = i + hh - 1;
-      cv->c_yoff = i;
-      i += hh + 1;
-      h -= hh + 1;
     }
+        else {  /* Grow the regions from below (the right). */
+            switch (fore -> c_type) {
+            case HORIZONTAL: 
+                if ( !(new_fore = squeeze(list, fore, UP, 0)))
+                    new_fore = squeeze(list, fore, LEFT, 0); 
+                break;
+            case VERTICAL:   
+                if ( !(new_fore = squeeze(list, fore, LEFT, 0)))
+                    new_fore = squeeze(list, fore, UP, 0);
+	    break;
+	}
+    }
+        ASSERT (new_fore);
+        return new_fore;
+    }
+}
+
+
+void
+RemCanvas()
+{   /** Remove the foreground canvas. */
+
+    struct screen_region  vr; /*Canvasses in the same row/column as D_forecv.*/
+    struct canvas *new_fore;  /* Canvas which will replace D_forecv. */
+
+    /* Do nothing if the foreground is the only canvas. */
+    if (D_cvlist->c_next == NULL)
+        return;
+
+    compute_region(D_forecv->c_type, &vr, D_forecv, D_cvlist);
+
+    debug1("RemCanvas. count = %d\n",vr.count);
+    debug_print_all_canvasses("RemCanvas() start\n");
+
+    if (vr.count > 1) {  /* Resize the neighboring canvas in region. */
+        debug2("D_forecv = %x  vr.start = %x\n",D_forecv, vr.start);
+        /* If there is a canvas before D_forecv, then
+        grow that canvas to take up the space. */
+        if (D_forecv != vr.start) {
+            struct canvas *pred;  /* Predecssor of D_forecv. */
+            for (pred = vr.start; pred->c_next != D_forecv; )
+                pred = pred->c_next;
+
+            new_fore         = pred;
+            new_fore -> c_ye = D_forecv->c_ye;
+            new_fore -> c_xe = D_forecv->c_xe;
+
+        } 
+        else {
+            new_fore           = D_forecv -> c_next;
+            new_fore -> c_ys   = D_forecv -> c_ys;
+            new_fore -> c_xs   = D_forecv -> c_xs;
+            new_fore -> c_yoff = new_fore -> c_ys;
+            new_fore -> c_xoff = new_fore -> c_xs;
+        }
+    }
+    else { /* Resize all bordering regions. */
+        new_fore = grow_surrounding_regions( D_cvlist, D_forecv,0);
+    }
+    debug_print_canvas(new_fore);
+
+    /* Redirect all pointers in the list. */
+    redirect_pointers(D_cvlist, D_forecv, new_fore);
+
+    remove_canvas_from_list(&D_cvlist, D_forecv);
+    FreeCanvas(D_forecv);
+    D_forecv = new_fore;
+    D_fore   = Layer2Window(D_forecv->c_layer);
+    flayer   = D_forecv->c_layer;
+
+    debug2("RemCanvas. forecv = %#x  new_fore = %#x\n", D_forecv, new_fore);
+    debug_print_all_canvasses("RemCanvas() end.\n");
+
   RethinkDisplayViewports();
   ResizeLayersToCanvases();
 }
 
 void
-OneCanvas()
-{
-  struct canvas *mycv = D_forecv;
-  struct canvas *cv, **cvpp;
+OneCanvas(list, target)
+struct canvas **list;
+struct canvas  *target;
+{   /* Free all canvasses in the list except for
+    target.  Make *list reference target. */
+    struct canvas  *cv;
+    struct canvas *next;
 
-  for (cvpp = &D_cvlist; (cv = *cvpp);)
-    {
-      if (cv == mycv)
-        {
-	  cv->c_ys = 0;
-	  cv->c_ye = D_height - 1 - (D_has_hstatus == HSTATUS_LASTLINE) - captionalways;
-	  cv->c_yoff = 0;
-	  cvpp = &cv->c_next;
-        }
-      else
-        {
-	  *cvpp = cv->c_next;
+    debug_print_all_canvasses("OneCanvas start.\n");
+    for (cv = *list; cv; cv = next) {
+        next = cv -> c_next;
+        if (cv == target) {
+            cv -> c_xoff  = 0;
+            cv -> c_xs    = 0;
+            cv -> c_xe    = D_width-1;
+            cv -> c_yoff  = 0;
+            cv -> c_ys    = 0;
+            cv -> c_ye    = D_height - 1 - (D_has_hstatus ==
+                HSTATUS_LASTLINE) - captionalways;
+            cv -> c_left  = cv->c_right = NULL;
+            cv -> c_above = cv->c_below = NULL;
+            cv -> c_next    = NULL;
+        } else {
 	  FreeCanvas(cv);
         }
     }
+    *list = target;
+    debug_print_all_canvasses("OneCanvas end.\n");
+
   RethinkDisplayViewports();
   ResizeLayersToCanvases();
 }
--- display.h.orig	2003-07-01 14:01:42.000000000 +0000
+++ display.h	2006-07-07 02:39:25.000000000 +0000
@@ -58,6 +58,11 @@ struct canvas
   int              c_ys;
   int              c_ye;
   struct event     c_captev;	/* caption changed event */
+  int              c_type;     /* which type of split created the canvas. */
+  struct canvas   *c_right;    /* canvas to the right. */
+  struct canvas   *c_left;     /* canvas to the left.  */
+  struct canvas   *c_above;    /* canvas above. */
+  struct canvas   *c_below;    /* canvas below. */
 };
 
 struct viewport
--- extern.h.orig	2003-08-22 12:27:57.000000000 +0000
+++ extern.h	2006-07-07 02:39:25.000000000 +0000
@@ -289,9 +289,9 @@ extern void  NukePending __P((void));
 #endif
 extern void  SetCanvasWindow __P((struct canvas *, struct win *));
 extern int   MakeDefaultCanvas __P((void));
-extern int   AddCanvas __P((void));
+extern int   AddCanvas __P((int));
 extern void  RemCanvas __P((void));
-extern void  OneCanvas __P((void));
+extern void  OneCanvas __P((struct canvas **, struct canvas *));
 extern int   RethinkDisplayViewports __P((void));
 extern void  RethinkViewportOffsets __P((struct canvas *));
 #ifdef RXVT_OSC
@@ -490,3 +490,16 @@ extern int   PrepareEncodedChar __P((int
 # endif
 #endif
 extern int   EncodeChar __P((char *, int, int, int *));
+extern int   compute_region __P((int,struct screen_region *, struct canvas *, struct canvas *));
+extern void  reset_region_types __P((struct screen_region *, int));
+extern void  equalize_canvas_dimensions __P((struct screen_region *));
+extern int   adjust_canvas_dimensions __P((struct screen_region *, struct canvas *, int));
+enum directions {
+    LEFT,
+    RIGHT,
+    UP,
+    DOWN
+};
+
+extern struct canvas * squeeze __P(( struct canvas *, struct canvas *,
+    enum directions, int  distance));
--- process.c.orig	2003-09-18 12:53:54.000000000 +0000
+++ process.c	2006-07-07 02:39:26.000000000 +0000
@@ -548,6 +548,7 @@ InitKeytab()
   ktab['B'].nr = RC_POW_BREAK;
   ktab['_'].nr = RC_SILENCE;
   ktab['S'].nr = RC_SPLIT;
+  ktab['V'].nr = RC_VERT_SPLIT;
   ktab['Q'].nr = RC_ONLY;
   ktab['X'].nr = RC_REMOVE;
   ktab['F'].nr = RC_FIT;
@@ -3649,7 +3650,11 @@ int key;
       break;
 #endif /* MULTIUSER */
     case RC_SPLIT:
-      AddCanvas();
+        AddCanvas(HORIZONTAL);
+        Activate(-1);
+        break;
+    case RC_VERT_SPLIT:
+        AddCanvas(VERTICAL);
       Activate(-1);
       break;
     case RC_REMOVE:
@@ -3657,7 +3662,7 @@ int key;
       Activate(-1);
       break;
     case RC_ONLY:
-      OneCanvas();
+      OneCanvas(&D_cvlist, D_forecv);
       Activate(-1);
       break;
     case RC_FIT:
@@ -5877,104 +5882,51 @@ static void
 ResizeRegions(arg)
 char *arg;
 {
-  struct canvas *cv;
-  int nreg, dsize, diff, siz;
+    struct screen_region  region;  /* Region in which D_forecv resides. */
+    int    adjusted;
+
+    /* Note: there's a nomenclature problem here.  I'm using 'region' 
+    to mean a set of canvasses that are related geographically
+    in the display.  The documentation uses 'region' to refer to
+    a single canvas (that's the usage in the error message
+    below). */
 
   ASSERT(display);
-  for (nreg = 0, cv = D_cvlist; cv; cv = cv->c_next)
-    nreg++;
-  if (nreg < 2)
-    {
-      Msg(0, "resize: need more than one region");
-      return;
-    }
-  dsize = D_height - (D_has_hstatus == HSTATUS_LASTLINE);
-  if (*arg == '=')
-    {
-      /* make all regions the same height */
-      int h = dsize;
-      int hh, i = 0;
-      for (cv = D_cvlist; cv; cv = cv->c_next)
-	{
-	  hh = h / nreg-- - 1;
-	  cv->c_ys = i;
-	  cv->c_ye = i + hh - 1;
-	  cv->c_yoff = i;
-	  i += hh + 1;
-	  h -= hh + 1;
-        }
-      RethinkDisplayViewports();
-      ResizeLayersToCanvases();
+    if (D_cvlist -> c_next == NULL) {
+        Msg(0, "More than one region required.");
       return;
     }
-  siz = D_forecv->c_ye - D_forecv->c_ys + 1;
-  if (*arg == '+')
-    diff = atoi(arg + 1);
-  else if (*arg == '-')
-    diff = -atoi(arg + 1);
-  else if (!strcmp(arg, "min"))
-    diff = 1 - siz;
-  else if (!strcmp(arg, "max"))
-    diff = dsize - (nreg - 1) * 2 - 1 - siz;
-  else
-    diff = atoi(arg) - siz;
-  if (diff == 0)
-    return;
-  if (siz + diff < 1)
-    diff = 1 - siz;
-  if (siz + diff > dsize - (nreg - 1) * 2 - 1)
-    diff = dsize - (nreg - 1) * 2 - 1 - siz;
-  if (diff == 0 || siz + diff < 1)
-    return;
 
-  if (diff < 0)
-    {
-      if (D_forecv->c_next)
-	{
-	  D_forecv->c_ye += diff;
-	  D_forecv->c_next->c_ys += diff;
-	  D_forecv->c_next->c_yoff += diff;
-	}
-      else
-	{
-	  for (cv = D_cvlist; cv; cv = cv->c_next)
-	    if (cv->c_next == D_forecv)
+    compute_region(D_forecv->c_type, &region, D_forecv, D_cvlist);
+    reset_region_types(&region, D_forecv->c_type);
+
+    if (region.count > 1) {
+        switch (*arg) {
+        case '=': equalize_canvas_dimensions(&region); break;
+        case '-': adjust_canvas_dimensions(&region, D_forecv, -atoi(arg+1)); break;
+        case '+': 
+            adjusted = adjust_canvas_dimensions(&region, D_forecv, atoi(arg+1)); 
 	      break;
-	  ASSERT(cv);
-	  cv->c_ye -= diff;
-	  D_forecv->c_ys -= diff;
-	  D_forecv->c_yoff -= diff;
-	}
-    }
-  else
-    {
-      int s, i = 0, found = 0, di = diff, d2;
-      s = dsize - (nreg - 1) * 2 - 1 - siz;
-      for (cv = D_cvlist; cv; i = cv->c_ye + 2, cv = cv->c_next)
-	{
-	  if (cv == D_forecv)
-	    {
-	      cv->c_ye = i + (cv->c_ye - cv->c_ys) + diff;
-	      cv->c_yoff -= cv->c_ys - i;
-	      cv->c_ys = i;
-	      found = 1;
-	      continue;
+        case 'm':
+            if (!strcmp(arg, "min"))
+                adjust_canvas_dimensions(&region, D_forecv, -region.expanse);
+            else if (!strcmp(arg, "max"))
+                adjust_canvas_dimensions(&region, D_forecv, region.expanse);
+	      break;
+        default:
+            Msg(0, "resize: arguments munged");
 	    }
-	  s -= cv->c_ye - cv->c_ys;
-	  if (!found)
-	    {
-	      if (s >= di)
-		continue;
-	      d2 = di - s;
 	    }
-	  else
-	    d2 = di > cv->c_ye - cv->c_ys ? cv->c_ye - cv->c_ys : di;
-	  di -= d2;
-	  cv->c_ye = i + (cv->c_ye - cv->c_ys) - d2;
-	  cv->c_yoff -= cv->c_ys - i;
-	  cv->c_ys = i;
+    else {
+        /*TODO Need to expand this canvas into surrounding regions...*/
+        switch(*arg) {
+        case '=': Msg(0, "More than one region required."); return;
+        // http://lists.gnu.org/archive/html/screen-users/2006-06/msg00012.html
+        // case '-': squeeze(D_cvlist, D_forecv, RIGHT, atoi(arg+1)); break;
+        default : Msg(0, "More than one region required."); return;
         }
     }
+
   RethinkDisplayViewports();
   ResizeLayersToCanvases();
 }
--- screen.h.orig	2003-08-22 12:28:43.000000000 +0000
+++ screen.h	2006-07-07 02:39:26.000000000 +0000
@@ -288,8 +288,25 @@ struct baud_values
   int sym;	/* symbol defined in ttydev.h */
 };
 
+struct screen_region {
+    /* This is a group of canvasses that are all in 
+    the same column or row. */
+    struct canvas *start;   /* First canvas in the region. */
+    struct canvas *end;     /* Last canvas in the region. */
+    int            expanse; /* Range in the appropriate direction. */
+    int            count;   /* Number of canvasses in the region. */
+    int            type;    /* HORIZONTAL or VERTICAL. */
+    int            xs;      /* starting x coordinate */
+    int            xe;      /* ending   x coordinate */
+    int            ys;      /* starting y coordinate */
+    int            ye;      /* ending   y coordinate */
+};
+
 /*
  * windowlist orders
  */
 #define WLIST_NUM 0
 #define WLIST_MRU 1
+
+#define HORIZONTAL 0
+#define VERTICAL 1
