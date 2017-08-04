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
$self.stack[^table::create{id:ln:name:file:file_path:file_name:lineno:colno}[ $.separator[:] ]]

# @{hash} [files]
$self.files[^hash::create[]]

# @{hash} [lines]
$self.lines[^hash::create[
	$.half(0)
	$.count(1)
]]

# @{hash} [$self.exception]
$self.exception[^hash::create[]]

# @{hash} [colors]
$self.colors[^hash::create[
	$.brackets[#0000AA]
	$.reservedWord[#0000AA]
	$.methodDefine[#990000]
	$.methodCall[#AA0000]
	$.html[#0077DD]
	$.service[#990000]
	$.var[#CC0000]
	$.result[#D27C00]
	$.comment[#808080]
	$.inParser[#555555]
]]

# @{hash} [reservedWords]
$self.reservedWords[^hash::create[
	$.if(1)
	$.switch(1)
	$.case(1)
	$.for(1)
	$.while(1)
	$.taint(1)
	$.untaint(1)
	$.try(1)
	$.throw(1)
	$.eval(1)
	$.process(1)
	$.cache(1)
	$.use(1)
	$.connect(1)
]]

# @{hash} [_system]
$self._system[^hash::create[
	$.fields[
		$.now(true)
		$.root(true)
		$.debug(true)
		$.status(true)
		$.stack(true)
		$.files(true)
		$.lines(true)
		$.exception(true)
		$.colors(true)
		$.reservedWords(true)
		$._system(true)
	]
	$.template[^file:dirname[^self.normalizePath[$path]]/templates/exception.html]
]]
#end @auto[]



###############################################################################
# @PUBLIC
###############################################################################
@render[params][locals]
$params[^hash::create[$params]]

^if($params.debug is bool){
	$self.debug(^params.debug.bool(false))
}($params.debug is junction){
	$self.debug(^params.debug[])
}

^if(def $params.lines){
	$self.lines.count(^params.lines.int(0))

	^if($self.lines.count > 1){
		$self.lines.half(^math:floor($self.lines.count / 2))
	}
}

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

		^if(!def $self.exception.file_path || $self.exception.file_path eq ""){
			$self.exception.file_path[/]
		}{
			$self.exception.file_path[${self.exception.file_path}/]
		}

		$self.exception.file_name[^file:basename[$_path]]
	}
}

^if($self.debug && def $params.stack && $params.stack is table){
	$_ln(^params.stack.count[])

	^params.stack.menu{
		$_id[^math:md5[$params.stack.file]]
		$_path[^self.normalizePath[$params.stack.file]]

		^self.stack.append[^hash::create[
			$.ln[$_ln]
			$.id[$_id]
			$.name[$params.stack.name]
			$.file[$params.stack.file]
			$.file_path[^file:dirname[$_path]]
			$.file_name[^file:basename[$_path]]
			$.lineno[$params.stack.lineno]
			$.colno[$params.stack.colno]
		]]

		^self.files.add[
			$.[$_id][^self._loadFile[$_path]]
		]

		^_ln.dec[]
	}
}

$result[^self._render[$params]]
#end @render[]


###############################################################################
@normalizePath[path][locals]
$result[$path]

^if(def $result){
	$result[^result.replace[${self.root}/;/]]
}
#end @normalizePath[]



###############################################################################
# @PRIVATE
###############################################################################
@_render[params][locals]
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
@_prepareTemplate[params][locals]
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
@_extend[params][locals]
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


###############################################################################
@_loadFile[path][locals]
$result[^hash::create[
	$.path[$path]
	$.data[]
]]

^try{
	^if(-f $path){
		$file[^file::load[text;$path]]
		$text[^taint[html][$file.text]]
		$result.data[^text.split[^#0A][v]]
	}
}{
	$exception.handled(true)
}
#end @_loadFile[]


###############################################################################
@_printCodeLine[data][locals]
$text[$data.text]

$result[
	<div class="code__line^if($data.line == $data.errorLine){ code__line_error}">
		<div class="code__line_n">$data.line</div>
		<div class="code__line_text">
			^if($data.line == $data.errorLine){
				$text[^text.replace[$data.errorCode;<b>$data.errorCode</b>]]
			}
			<pre>^self._formatCode[$text]</pre>
		</div>
	</div>
]
#end @_printCodeLine[]


###############################################################################
@_formatCode[code][locals]
$_str[$code]

$lUID[^math:uid64[]]

# Помечаем и "выкусываем" коментарии, заменяя их на уникальный идентификатор.
$lComB[^_str.match[(\^^rem{ .*? })][gx]]
^if($lComB){
	$_str[^_str.match[\^^rem{ .*? }][gx]{/%b$lUID%/}]
}

$lComL[^_str.match[^^(\# .* )^$][gmx]]
^if($lComL){
	$_str[^_str.match[^^\# .* ^$][gmx]{/%l$lUID%/}]
}

# HTML-теги
  $_str[^_str.match[(</? \w+\s? .*? /? >)][gx]{^self._makeHTML[$match.1]}]

# Служебные конструкции
$_str[^_str.match[^^(@ (?:BASE|USE|CLASS|OPTIONS) )^$][gmx]{^self._makeService[$match.1]}]

# Описание методов
$_str[^_str.match[^^(@ [\w\-]+ \[ [\w^;\-]* \] (?:\[ [\w^;\-]* \])? ) (.*)^$][gmx]{^self._makeMethodDefine[$match.1;$match.2]}]

# Вызов методов
$_str[^_str.match[(\^^ [\w\-\.\:]+)][gx]{^self._makeMethodCall[$match.1]}]

# Переменные
$_str[^_str.match[(\^$ \{? [\w\-\.\:]+ \}?)][gx]{^self._makeVar[$match.1]}]

# Скобки
$_str[^_str.match[([\[\]\{\}\(\)]+)][g]{^self._makeBrackets[$match.1]}]

# Доделываем коментарии
^if($lComB){
	$_str[^_str.match[/%b$lUID%/][g]{^self._makeComment[$lComB.1]^lComB.offset(1)}]
}

^if($lComL){
	$_str[^_str.match[/%l$lUID%/][g]{^self._makeComment[$lComL.1]^lComL.offset(1)}]
}

$result[$_str]
#end @_formatCode[]


##############################################################
# Обрабатываем конструкции языка...
@_makeComment[aStr]
^if(^aStr.left(2) eq "##"){
	$result[<font color="$self.colors.inParser"><i>$aStr</i></font>]
}{
	$result[<font color="$self.colors.comment"><i>$aStr</i></font>]
}

@_makeHTML[aStr]
	$result[<font color="$self.colors.html">$aStr</font>]

@_makeService[aStr]
	$result[<font color="$self.colors.service">$aStr</font>]

@_makeBrackets[aStr]
	$result[<font color="$self.colors.brackets">$aStr</font>]

@_makeVar[aStr]
^if($aStr eq "^$result"){
	$result[<font color="$self.colors.result">$aStr</font>]
}{
	$result[<font color="$self.colors.var">$aStr</font>]
}

@_makeMethodDefine[aStr;aAdd]
	$result[<font color="$self.colors.methodDefine"><b>$aStr</b></font>^_makeComment[$aAdd]]

@_makeMethodCall[aStr]
## Разделяем вызовы стандартных методов и вызовы пользовательских методов
^if($_reservedWords.[^aStr.mid(1)] || ^aStr.left(6) eq "^^MAIN:" || ^aStr.left(6) eq "^^BASE:"){
	$result[<font color="$self.colors.reservedWord">$aStr</font>]
}{
	$result[<font color="$self.colors.methodCall">$aStr</font>]
}
