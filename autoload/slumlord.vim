if exists("g:slumlord_plantuml_jar_path")
    let s:jar_path = g:slumlord_plantuml_jar_path
else
    let s:jar_path = expand("<sfile>:p:h") . "/../plantuml.jar"
endif

let s:divider = "@startuml"

function! slumlord#updatePreview(args) abort
    if !s:shouldInsertPreview()
        return
    end

    let tmpfname = tempname()
    call s:mungeDiagramInTmpFile(tmpfname)
    let b:slumlord_preview_fname = fnamemodify(tmpfname,  ':r') . '.utxt'


    let cmd = "java -jar ". s:jar_path ." -tutxt " . tmpfname

    let write = has_key(a:args, 'write') && a:args["write"] == 1
    if exists("*jobstart")
        call jobstart(cmd, { "on_exit": function("s:asyncHandlerAdapter"), "write": write, "bufnr": bufnr("") })
    else
        call system(cmd)
        if v:shell_error == 0
            call s:updateBuffer(a:args)
        endif
    endif
endfunction

function! s:shouldInsertPreview() abort
    "check for 'no-preview flag
    if search('^\s*''no-preview', 'wn') > 0
        return
    endif

    "check for state diagram
    if search('^\s*\[\*\]', 'wn') > 0
        return
    endif

    "check for use cases
    if search('^\s*\%((.*)\|:.*:\)', 'wn') > 0
        return
    endif

    "check for class diagrams
    if search('^\s*class\>', 'wn') > 0
        return
    endif

    "check for activity diagrams
    if search('^\s*:.*;', 'wn') > 0
        return
    endif

    return s:dividerLnum()
endfunction

function! s:dividerLnum() abort
    return search(s:divider, 'wn')
endfunction

function! s:asyncHandlerAdapter(job_id, data, event) abort dict
    if a:data != 0
        return 0
    endif

    if bufnr("") != self.bufnr
        return 0
    endif

    call s:updateBuffer(self)
endfunction

"args: a dict containing keys
"   'write' - write the buffer after updating
function! s:updateBuffer(args) abort
    let startLine = line(".")
    let lastLine = line("$")
    let startCol = col(".")

    call s:deletePreviousDiagram()
    call s:insertDiagram(b:slumlord_preview_fname)
    call s:addTitle()

    call cursor(line("$") - (lastLine - startLine), startCol)

    if a:args['write']
        noautocmd write
    endif
endfunction

function! s:deletePreviousDiagram() abort
    if s:dividerLnum() > 1
        exec '0,' . (s:dividerLnum() - 1) . 'delete'
    endif
endfunction

function! s:insertDiagram(fname) abort
    call append(0, "")
    call append(0, "")
    0

    call s:readWithoutStoringAsAltFile(a:fname)

    "fix trailing whitespace
    exec '1,' . s:dividerLnum() . 's/\s\+$//e'

    call s:removeLeadingWhitespace()
endfunction

function! s:readWithoutStoringAsAltFile(fname) abort
    let oldcpoptions = &cpoptions
    set cpoptions-=a
    exec "read " . a:fname
    let &cpoptions = oldcpoptions
endfunction

function! s:mungeDiagramInTmpFile(fname) abort
    execute "write " . a:fname
    call s:convertNonAsciiSupportedSyntax(a:fname)
endfunction

function! s:convertNonAsciiSupportedSyntax(fname) abort
    let oldbuf = bufnr("")

    exec 'edit ' . a:fname
    let tmpbufnr = bufnr("")

    /@startuml/,/@enduml/s/^\s*\(boundary\|database\|entity\|control\)/participant/e
    /@startuml/,/@enduml/s/^\s*\(end \)\?\zsref\>/note/e
    /@startuml/,/@enduml/s/^\s*ref\>/note/e
    /@startuml/,/@enduml/s/|||/||4||/e
    /@startuml/,/@enduml/s/\.\.\.\([^.]*\)\.\.\./==\1==/e
    write

    exec oldbuf . "buffer"
    exec tmpbufnr. "bwipe!"
endfunction

function! s:removeLeadingWhitespace() abort
    let smallestLead = 100

    for i in range(1, s:dividerLnum()-1)
        let lead = match(getline(i), '\S')
        if lead >= 0 && lead < smallestLead
            let smallestLead = lead
        endif
    endfor

    exec '1,' . s:dividerLnum() . 's/^ \{'.smallestLead.'}//e'
endfunction

function! s:addTitle() abort
    let lnum = search('^title ', 'n')
    if !lnum
        return
    endif

    let title = substitute(getline(lnum), '^title \(.*\)', '\1', '')

    call append(0, "")
    call append(0, repeat("^", len(title)+6))
    call append(0, "   " . title)
endfunction
