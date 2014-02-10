# Page Definition Specification

A "page definition" is a term used internally to represent a page of information you'd like displayed on multiple LED signs.  This page of information likely is both wider and longer than the number of signs you have can accomodate.

For example:

``` Text
RACE RESULTS
1. Eric 10 seconds
2. Mike 11 seconds
3. Justin 15 seconds
4. Dan 20 seconds
```

If you have 4 LED signs arranged vertically:

``` text
[                ]
[                ]
[                ]
[                ]
```

The 5 lines on the page above won't fit at one time.  So, we need to break things up into lines and screens...which can be rendered into something displayable on the screens.

So, for the page above, it might get rendered as follows:

``` text
# First
[RACE RESULTS    ]
[1. Eric 10 seconds]
[2. Mike 11 seconds]
[3. Justin 15 seconds]

# Second
[4. Dan 20 seconds]
[                ]
[                ]
[                ]
```

Notice, we broke up the 5 lines into 2 four line screenfulls (with 3 blank lines on the second screenful).

To specify this as a page definition YAML, we'd write the following:

``` YAML
---
title: RACE RESULTS
lines:
- prefix: '1. '
  content:
  - Eric
  - 10 seconds
- prefix: '2. '
  content:
  - Mike
  - 11 seconds
- prefix: '3. '
  content:
  - Justin
  - 15 seconds
- prefix: '4. '
  content:
  - Dan
  - 20 seconds
```

A page definition consists of the following:

* `title`
  * Title to be displayed when showing this page of the information (it will stick to the stop LED sign)
* `lines`
  * An array of line definitions
  * `prefix`
      * If the content of one line is too long for a single screen, each screen of information will be prefixed with this text
  * `content`
      * An array of screen fulls of information.  Each element of the array will be displayed in it's own screen.

Given the page definition above, the page would render as follows:

``` text
# First

[RACE RESULTS    ]
[1. Eric         ]
[2. Mike         ]
[3. Justin       ]

# Second

[RACE RESULTS    ]
[1. 10 seconds   ]
[2. 11 seconds   ]
[3. 15 seconds   ]

# Third

[RACE RESULTS    ]
[4. Dan          ]
[                ]
[                ]
[                ]

# Fourth

[RACE RESULTS    ]
[1. 20 seconds   ]
[                ]
[                ]
[                ]
```

Play around with it and see how things render!  The "truth" is in [MultiMovingsign::PageRender page_renderer.rb](lib/multi_movingsign/page_renderer.rb) and in the related [test cases](lib/multi_movingsign/page_renderer.rb).

Pull requests and fixes welcome.