*! version 1.0.1  18Feb1998   STB-44 sg86
program define ocrpred
	version 5.0

	if "$S_E_cmd"!="ocratio" { error 301 }

	local varlist "req new"
	local if "opt"
	local in "opt"
	local options "XB PRob"

	* Rename any new variables to temporary names
	nobreak{
		parse "`*'"
		parse "`varlist'", parse(" ")
		local i 1
		while "``i''"~="" {
			tempname v`i'
			rename ``i'' `v`i''
			local i = `i'+1
			}
		}

	* Do some checks on the input to the command
	if ("`xb'"~="" & "`prob'"~=""){
		di in red "Two options cannot be specified simultaneously"
		exit 499
		}
	if "`xb'"=="" & "`prob'"=="" { local xb "xb" }
	if "`xb'"~="" { 
		capture assert "`2'"==""
		if _rc~=0 { error 103 }
		}
	if "`prob'"=="prob" {
		if `i'-1<$S_3 { error 102 } 
		if `i'-1>$S_3 { error 103 } 
		}

	tempvar s touse
	mark `touse' `if' `in'
	markout `touse' $S_E_rhs

	* Generate the linear predictor 
	quietly { 
		tempname allcoef coef zero
		mat `allcoef' = get(_b)
		mat `coef'  = `allcoef'[1,$S_3...]
		local nvar = colsof(`coef')
		mat `zero' = J(1,`nvar',0)
		mat `coef' = `zero' - `coef'
		mat score `s' = `coef' if `touse'

		if "`xb'"=="xb" {
			rename `s' `1'
			label var `1' "Linear predictor"
			exit
			}
		}

	* Calculate predicted probabilities (held in temporary v`i' variables)
	quietly {
		if "$S_E_link" == "logit" { local invlink "1/(1+exp(-" }
		if "$S_E_link" == "probit" { local invlink "normprob((" }
		if "$S_E_link" == "cloglog" { local invlink "1-exp(-exp(" }
		replace `v1' = `invlink'(_b[_cut1]-`s')))
		label var `v1' "Pr(1st category)"
		tempvar cum
		gen double `cum' = 1-`v1'
		local i 1 
		while `i'<$S_3-1 { 
			local i=`i'+1
			replace `v`i'' = (`invlink'(_b[_cut`i']-`s'))))*`cum'
			_Get_nth, value(`i')
			label var `v`i'' "Pr($S_nth category)"
			replace `cum'= `cum' - `v`i''
		}
		local i = `i'+1
		replace `v`i''=`cum'
		_Get_nth, value(`i')
		label var `v`i'' "Pr($S_nth category)"
		local i 1
		while `i'<=$S_3 { 
			rename `v`i'' ``i''
			local i=`i'+1
			}
		}
end


program define _Get_nth
	local options "Value(int 1)"
	parse "`*'"
	if substr("`value'",-1,1)=="1" & substr("`value'",-2,1)~="1" { global S_nth "`value'st" }
	else if substr("`value'",-1,1)=="2" & substr("`value'",-2,1)~="1" { global S_nth "`value'nd" }
	else if substr("`value'",-1,1)=="3" & substr("`value'",-2,1)~="1" { global S_nth "`value'rd" }
	else { global S_nth "`value'th" }
end
