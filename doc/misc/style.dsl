<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
<!ENTITY html-ss PUBLIC "-//Norman Walsh//DOCUMENT DocBook HTML Stylesheet//EN" CDATA dsssl>
<!ENTITY print-ss PUBLIC "-//Norman Walsh//DOCUMENT DocBook Print Stylesheet//EN" CDATA dsssl>
]>

<style-sheet>

<style-specification id="print" use="print-stylesheet">
<style-specification-body> 
;; customize the html stylesheet
</style-specification-body>
</style-specification>

<style-specification id="html" use="html-stylesheet">
<style-specification-body>

      (define %stylesheet% "docbook.css")

</style-specification-body>
</style-specification>


<style-specification id="rawhtml" use="html-stylesheet">
<style-specification-body>

(define %header-navigation% #f)
(define %footer-navigation% #f)

</style-specification-body>
</style-specification>

      
<external-specification id="print-stylesheet" document="print-ss">
<external-specification id="html-stylesheet" document="html-ss">

</style-sheet>
