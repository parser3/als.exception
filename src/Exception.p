###############################################################################
# $ID: Exception.p, 22 Sep 2016 15:32, Leonid 'n3o' Knyazev $
###############################################################################
@CLASS
Als/Exception


@OPTIONS
locals



###############################################################################
@auto[path][locals]
# @{object} [now]
$self.now[^date::now[]]

# @{string} [root]
^if(def $env:PWD){
	$self.root[^env:PWD.trim[right;/]]
}(def $env:DOCUMENT_ROOT_VIRTUAL){
	$self.root[^env:DOCUMENT_ROOT_VIRTUAL.trim[right;/]]
}(def $env:DOCUMENT_ROOT){
	$self.root[^env:DOCUMENT_ROOT.trim[right;/]]
}

# @{bool} [debug]
$self.debug(false)

# @{int} [status]
$self.status(500)

# @{table} [stack]
$self.stack[^table::create{ln:name:file:file_path:file_name:lineno:colno}[ $.separator[:] ]]

# @{hash} [$self.exception]
$self.exception[^hash::create[]]

# @{hash} [_system]
$self._system[^hash::create[
	$.fields[
		$.now(true)
		$.root(true)
		$.debug(true)
		$.status(true)
		$.stack(true)
		$.exception(true)
		$._system(true)
	]
	$.template[^file:dirname[^self.normalizePath[$path]]/templates/exception.html]
]]
#end @auto[]



###############################################################################
# @PUBLIC
###############################################################################
@render[params]
$params[^hash::create[$params]]

$self.debug(^params.debug.bool(false))

^if(def $params.exception && $params.exception is hash){
	$self.exception[^hash::create[$params.exception]]

	^if(def $self.exception.type && $self.exception.type eq "file.missing"){
		$self.status(404)
	}

	^if(!def $self.exception.source){
		$self.exception.source[Unhandled Exception]
	}{
		$self.exception.source[^self.normalizePath[$self.exception.source]]
	}

	^if(def $self.exception.comment){
		$self.exception.comment[^self.normalizePath[$self.exception.comment]]
		$self.exception.comment[^untaint[html]{$self.exception.comment}]
	}

	^if(def $self.exception.file){
		$_path[^self.normalizePath[$self.exception.file]]

		$self.exception.file_path[^file:dirname[$_path]]
		$self.exception.file_name[^file:basename[$_path]]
	}
}

^if(def $params.stack && $params.stack is table){
	$_ln(^params.stack.count[])

	^params.stack.menu{
		$_path[^self.normalizePath[$params.stack.file]]

		^self.stack.append[^hash::create[
			$.ln[$_ln]
			$.name[$params.stack.name]
			$.file[$params.stack.file]
			$.file_path[^file:dirname[$_path]]
			$.file_name[^file:basename[$_path]]
			$.lineno[$params.stack.lineno]
			$.colno[$params.stack.colno]
		]]

		^_ln.dec[]
	}
}

$result[^self._render[$params]]
#end @render[]


###############################################################################
@normalizePath[path]
$result[$path]

^if(def $result){
	$result[^result.replace[${self.root}/;/]]
}
#end @normalizePath[]



###############################################################################
# @PRIVATE
###############################################################################
@_render[params]
$response:status(^self.status.int(500))

$response:content-type[
	$.value[text/html]
	$.charset[$response:charset]
]

$template[^self._prepareTemplate[$params]]

^if(-f $template.path){
	$_template[^file::load[text;${template.path}]]

	^if(def $_template.text){
		^self._extend[$params]

		$result[^process[$self]{^untaint[as-is]{^_template.text.trim[]}}[
			$.file[${template.path}]
		]]
	}
}

^if(!def $result && $template.method is junction){
	$result[^template.method[$self.exception;$self.stack]]
}
#end @_render[]


###############################################################################
@_prepareTemplate[params]
$result[^hash::create[]]

^if(!def $params.template || !-f "${params.template}"){
	$params.template[$self._system.template]
}

$_path[^file:dirname[$params.template]]
$_name[^file:justname[$params.template]]
$_ext[^file:justext[$params.template]]

^if($self.debug && -f "${_path}/${_name}.debug.${_ext}"){
	$result.path[${_path}/${_name}.debug.${_ext}]
}{
	$result.path[${_path}/${_name}.${_ext}]
}

^if($self.debug){
	$result.method[$MAIN:unhandled_exception_debug]
}{
	$result.method[$MAIN:unhandled_exception_release]
}
#end @_prepareTemplate[]


###############################################################################
@_extend[params]
$_extends[^hash::create[$params.extends]]

^if($MAIN:unhandled_exception_extend is junction){
	$_exception_extend[^MAIN:unhandled_exception_extend[]]

	^if(def $_exception_extend && $_exception_extend is hash){
		^_extends.add[$_exception_extend]
	}
}

^_extends.foreach[name;data]{
	^if(!^self._system.fields.contains[$name]){
		$self.[$name][$data]
	}
}


# request info
$self.request[^hash::create[]]

$self.request.time[${self.now.hour}:^self.now.minute.format[%.02u]:^self.now.second.format[%.02u]]
$self.request.remote[^if(def $env:REMOTE_HOST && $env:REMOTE_HOST ne $env:REMOTE_ADDR){REMOTE_ADDR: $env:REMOTE_ADDR REMOTE_HOST: $env:REMOTE_HOST}{$env:REMOTE_ADDR}]
$self.request.parser[^env:PARSER_VERSION.match[compiled on ][]{}]

$uriParam[^request:uri.match[^^[^^\?]*\??(.*)?][]{$match.1}]
$uriParam[^uriParam.split[&]]

$queryParam[$request:query]
$queryParam[^queryParam.split[&]]

$uriParamCount(0)
$queryParamCount(^queryParam.count[]-^uriParam.count[])

^if($form:tables is "hash"){
	^form:tables.foreach[;val]{
		^uriParamCount.inc(^val.count[])
	}
}

$self.request.getCount(^uriParam.count[])
$self.request.postCount(^eval($uriParamCount-^queryParam.count[]))
$self.request.queryCount($queryParamCount)
$self.request.cookiesCount(^cookie:fields._count[])
#end @_extend[]
