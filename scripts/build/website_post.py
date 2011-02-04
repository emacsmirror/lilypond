#!@PYTHON@
#-*- coding: utf-8 -*-

##### This is web_post.py. This script deals with translations
##### in the "make website" target.

import sys
import os
import glob
import re

###### Translation data, move out, see create-weblinks-itexi.py
translations = {
    'cs': {
        'English': 'Česky',
        'Other languages': 'Other languages',
        },
    'de': {
        'English': 'Deutsch',
        'Other languages': 'Andere Sprachen',
        },
    'es': {
        'English': 'Español',
        'Other languages': 'Otros idiomas',
        },
    'fr': {
        'English': 'Français',
        'Other languages': 'Autres langues',
        },
    'hu': {
        'English': 'Magyar',
        'Other languages': 'Más nyelvek',
        },
    'it': {
        'English': 'Italiano',
        'Other languages': 'Altre lingue',
        },
    'ja': {
        'English': '日本語',
        'Other languages': '他の言語',
        },
    'nl': {
        'English': 'Nederlands',
        'Other languages': 'Andere talen',
        },
    'zh': {
        'English': '中文',
        'Other languages': '其它语言',
        },
    }

# needs at least: make -C po or make- C Documentation/po
HAVE_GETTEXT = False

####  this breaks on lilypond.org
# Keep some freakin' gettext compatibility
#if HAVE_GETTEXT:
#    import lilylib as ly;
#    global _;_=ly._
#else: # poor mans translation
#    def _ (string, lang=os.environ['LANG']):
#        return translations.get (lang.split ('_')[0], {}).get (string, string)

#### this works on lilypond.org
def _ (string, lang):
    return translations.get (lang.split ('_')[0], {}).get (string, string)


exclude_manuals = [
    '/music-glossary',
    '/snippets',
    '/internals',
    '/contributor'
]

###### Actual program

dir = sys.argv[1]

os.chdir(dir)
html_files = glob.glob( '*.html' )


### messy way to get all languages
langs_set = set()
for file in html_files:
    file_split = file.split('.')
    if (len(file_split) == 2):
        # it's English
        lang = ''
    elif (len(file_split) == 3):
        # it's a translation
        lang = file_split[1]
    # make sure it's a translated language
    if lang != "en":
        langs_set.add(lang)
langs = list(langs_set)
langs.sort()


### helper functions
def addLangExt(filename, lang, ext):
    text = filename
    exclude = 0
    for dir in exclude_manuals:
        if (text.find(dir) >= 0):
            exclude = 1
    if (not (exclude or (lang==""))):
        text += "." + lang
    text += "." + ext
    return text

def makeFooter (filename, currentLang):
    # TODO: add link to automatic language selection?
    # still need to include this page in the new webpages somewhere
    footer = '''<p id="languages">
%(other)s: %(lst)s.
</p>
'''
    def link (lang):
        str = '''<a href="%(file_name)s">%(language_name)s</a>'''
        file_name = addLangExt (filename, lang, 'html')
        language_name = _ ('English', lang)
        return str % locals ()
    lst = ', '.join ([link (lang) for lang in langs if lang != currentLang])
    other = _ ('Other languages', currentLang)
    return footer % locals ()

def getLocalHref(line):
    match = re.search(r'href=[\'"]?([^\'" >]+)', line)
    if match:
        url = match.group(0)[6:]
        if (url[0:7] == "http://"):
            url = ''
        # strip any '#'
        omit = url.find('#')
        if (omit >= 0):
            url = url[0:omit]
    else:
        url = ''
    return url




### main loop
for file in html_files:
    ### we want to strip the .html and get the lang
    file_split = file.split('.')
    file_base = os.path.basename( file_split[0] )
    if (len(file_split) == 2):
        # it's English
        lang = ''
        # possibly necessary for automatic language selection
        file_symlink = file.replace(".html", ".en.html")
        if (not (os.path.exists(file_symlink))):
            os.symlink (file, file_symlink)
    elif (len(file_split) == 3):
        # it's a translation
        lang = file_split[1]
        if (lang == "en"):
            # it's a symlink
            continue
    else:
        # it's a mess
        print "is a mess"
        continue

    ### we need to replace parts of the file
    lines = open(file).readlines()
    os.remove(file)
    outfile = open(file, 'w')

    lang_footer = makeFooter (file_base, lang)

    ### alter file
    for line in lines:
        ### alter links as appropriate
        link = getLocalHref(line)
        if (link != ""):
            # questionable
            if (not link.startswith("../doc/")):
                if (link.endswith(".html")):
	            langlink = addLangExt(link[:-5], lang, "html")
                    line = line.replace(link, langlink)
                if (link.endswith(".pdf")):
	            langlink = addLangExt(link[:-4], lang, "pdf")
                    line = line.replace(link, langlink)
        ### add google tracker header
        if (line.find("</head>") >= 0):
            outfile.write("""<!-- Google tracking !-->
<script src="http://www.google-analytics.com/urchin.js"
type="text/javascript">
</script>
<script type="text/javascript">
_uacct = "UA-68969-1";
urchinTracker();
</script>
""");
        #### add google tracker goals
        if (line.find("href=\"http://download.linuxaudio.org") >= 0):
            # TODO: more ugly hardcoding to make releases hard. :(
            if (line.find('2.12') >= 0):
                line = line.replace('a href=', 'a onClick=\"javascript:urchinTracker(\'/download/v2.12\');\" href=')
            elif (line.find('2.13') >= 0):
                line = line.replace('a href=', 'a onClick=\"javascript:urchinTracker(\'/download/v2.13\');\" href=')
        ### add language selection footer
        if (line.find("<div id=\"verifier_texinfo\">") >= 0):
            outfile.write("<div id=\"footer\">\n")
            outfile.write( lang_footer )
        if (line.find("</body") >= 0):
            outfile.write("</div>\n")
        outfile.write(line)
    outfile.close()

