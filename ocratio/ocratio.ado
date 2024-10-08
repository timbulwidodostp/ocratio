*! version 1.0.1  18Feb1998  Rory Wolfe   STB-44 sg86
program define ocratio

	version 5.0
	local options "Test CUMulative Level(real $S_level) Eform"

	if "`*'"=="" | substr("`1'",1,1)=="," { 
		if "$S_E_cmd"~="ocratio" { error 301 }
		parse "`*'"
		if "`cumulative'"~="" {
			capture assert "$S_E_link"~="logit" & "$S_E_link"~="probit"
			    if _rc~=0 {
				di in red "Cumulative option only available for cloglog model"
				exit 198
			    }
			}
		local exp "$S_E_wgt"
		local catvals "$S_E_yval"

		_Dires, cat($S_3) `cumulative' `eform' l(`level')
		global S_E_wgt `exp'
		global S_E_yval `catvals'
		global S_E_cmd "ocratio"
		if "`test'"=="test" { 
			if "$S_1"=="" | "$S_2"=="" {
				di in red "Test results not available"
				exit 302
				}
			else { _Ditest, link($S_E_link) lratio($S_1) df($S_2)}
			}
		exit
		}
	
	local depv `1'
	confirm variable `depv'
	macro shift
	local varlist "opt ex none"
	local if "opt"
	local in "opt"
	local weight "fweight"
	local options "`options' LInk(string)"
	parse "`*'"
	parse "`varlist'", parse(" ")

	if "`test'"=="test" & "`1'"=="" { 
		di in red "An explanatory variable must be provided to calculate test"
		exit 198
		}

	if "`link'"=="" {
		if "`cumulative'"~="" { local link "cloglog" }
		else { local link "logit" }
		}

	_Checks, link(`link') `eform' `cumulative'
	local link "$S_3"

	tempvar touse
	mark `touse' `if' `in' [`weight'`exp']
	markout `touse' `depv' `varlist'

	* Check response and create new response with category values 1,2,3,...
	quietly { 
		* Keep a record of original response category values
		tempname depvcat
		qui tab `depv', matrow(`depvcat')
		tempvar cat
		egen `cat' = group(`depv') if `touse'
		summ `cat'
		local n = _result(6)
		if `n'==0 {
			error 2000
		}
		if `n'==1 { 
			di in red "`depv' takes on only one value"
			exit 498
		}
		if `n'==2 { 
			di in red "`depv' takes on only two values"
			exit 498
		}
	}

	* Check for variables being dropped and omit them from further consideration
        _rmcoll `varlist' if `touse'
        local bnames "$S_1"
	preserve

	* Expand data and fit models
        quietly {
		keep if `touse'
		if "`weight'"!="" {
			tempvar wvar 
			gen double `wvar'`exp'
			compress `wvar'
			local weight "[`weight'=`wvar']"
		}
		keep `bnames' `cat' `wvar'
		tempvar id
		gen `id'=_n

		expand `n'

		sort `id'
		by `id': gen __cut=_n
		drop if `cat'<__cut
		tempvar crprop
		by `id': gen `crprop'=(`cat'==__cut)
		gen _cut1=(__cut==1)
		local g1 = `depvcat'[1,1]
		local catvals `g1'
		local i = 2
		while `i'<`n' {
			gen _cut`i'=(__cut==`i')
			local cuts "`cuts' _cut`i'"
			local g`i'=`depvcat'[`i',1]
			local catvals `catvals' `g`i''
			local i = `i'+1
			}
		local g`n'=`depvcat'[`i',1]
		local catvals `catvals' `g`n''

		* Fit baseline c-ratio link model (no covariates)
		tempvar inits 
		glm `crprop' _cut1 `cuts' `weight' if __cut!=`n' /*
			*/, f(b 1) l(`link') nocons ltol(1e-2)
		local l0 = -$S_3/2
		local df "$S_2"
		glmpred `inits'

		* Fit required c-ratio model 
		glm `crprop' _cut1 `cuts' `bnames' `weight' if __cut!=`n' /*
			*/, f(b 1) l(`link') nocons init(`inits')
		if "`test'"=="test" { 
			drop `inits'
			local dev = $S_3
			local dof = $S_2
			glmpred `inits' 
			}
		}

	global S_E_depv "`depv'"
	global S_E_l0 = `l0'
	global S_E_ll = -$S_3/2
	global S_E_mdf=`df'-$S_2
	global S_E_rhs "`bnames'"
	global S_E_link "`link'"

	_Dires, `cumulative' cat(`n') `eform' level(`level')

	parse "`exp'", parse(" =")
	global S_E_wgt `2'
	global S_E_yval `catvals'
	global S_E_cmd "ocratio"

	if "`test'"=="test" {
		tempname res
		estimates hold `res'
		parse "`bnames'", parse(" ")
		while "`1'"!="" {
			* Rename I* variables as they are erased by xi: before fitting
			* Also create new rhs for generalised model
			if substr("`1'",1,1)=="I" {
				local newname = substr("`1'",2,.)
				rename `1' `newname'
				local rhs "`rhs' i._cut1*`newname' i.__cut*`newname'" 
				}
			else { 	local rhs "`rhs' i._cut1*`1' i.__cut*`1'" }
			mac shift
			}

		quietly{
			* Fit the generalised model
			xi: glm `crprop' `rhs' `weight' if __cut!=`n', /*
				*/f(bin `tot') l(clog) nocons init(`inits') ltol(1e-2)
			local ratio = `dev' - $S_3
			local testdf = `dof'- $S_2
			}
		_Ditest, link(`link') lratio(`ratio') df(`testdf')
		estimates unhold `res'
		}

	global S_1 `ratio'
	global S_2 `testdf'
	global S_3 `n'
	global S_4 
	global S_5
	global S_6
	global S_7
end


program define _Dires

	local options "Eform CUMulative CAT(int 0) Level(int $S_level)"
	parse "`*'"

	local depv "$S_E_depv"
	local l0 "$S_E_l0"
	local ll "$S_E_ll"
	local mdf "$S_E_mdf"
	local bnames "$S_E_rhs"
	local nobs "$S_E_nobs"
	local link "$S_E_link"

	if "`cumulative'"=="" { local prob "Continuation-ratio" } 
	else                  { local prob "Ordered" } 
	#delimit ;
	di _n in gr "`prob' `link' Estimates " 
		_col(56) in gr "Number of obs = "  in ye %7.0g `nobs' ;
	di in gr _col(56) "chi2(" in ye %1.0f `mdf' in gr ")" _col(70) "= "
		in ye %7.2f -2*(`l0'-`ll') ;
	di in gr _col(56) "Prob > chi2   = " in ye %7.4f chiprob(`mdf',-2*(`l0'-`ll')) ;
	di in gr "Log Likelihood = " in ye %9.0g `ll' _col(56) in gr
		"Pseudo R2     = " in ye %7.4f 1-(`ll'/`l0') _n ;
	#delimit cr

	tempname b b2 var var2 zero
	mat `b' = get(_b) 
	mat `var' = get(VCE)
	* Output of covariate coefficients in the model
	if `cat'<colsof(`b')+1 {
		mat `b2' = `b'[1,`cat'...]
		local n2 = colsof(`b2')
		mat `zero' = J(1,`n2',0)
		mat `b2' = `zero' - `b2'
		mat colnames `b2' = `bnames'
		mat `var2' = `var'[`cat'...,`cat'...]
		mat colnames `var2' = `bnames'
		mat rownames `var2' = `bnames'

		matrix post `b2' `var2', depname(`depv')
		if "`eform'"~="" & "`link'"=="logit" { local ef "eform(Odds ratio)" }
		if "`eform'"~="" & "`link'"=="cloglog" {local ef "eform(Haz. ratio)" }
		matrix mlout, `ef' l(`level')
		}
	* Estimates header if no covariates in the model
	else {
	    di in gr _dup(78) "-"
	    di in gr "`depv'" _col(9) /*
		*/ " |      Coef.   Std. Err.       z     P>|z|       [95% Conf. Interval] "  
	    di in gr _dup(9) "-" "+" _dup(68) "-"
	}

	* Output of threshold parameters
	di in gr _col(2) "_cut1 " _col(10) "|" in ye _col(13) %9.8g `b'[1,1] _col(24) /*
		*/ %9.8g sqrt(`var'[1,1]) _col(46) in gr "(Ancillary parameters)"
	local i 2
	* Transformation to cut-points for cumulative cloglog model
	if "`cumulative'"~="" {
		tempname e1 est v1 v2 covjk
		scalar `e1' = exp(`b'[1,1])
		scalar `v1' = `e1'*`var'[1,1]
		while `i' < `cat' {
			tempname e`i'
			scalar `e`i'' = exp(`b'[1,`i'])
			scalar `est' = `e`i'' + `e1'
			scalar `v2' = `var'[`i',`i']*`e`i'' + `v1'
			local k = 1
			while `k'<`i' {
				scalar `covjk' = 2*`var'[`i',`k']*`e`i''*`e`k''/`est'
				local k = `k' + 1
				}
			scalar `v2' = `v2' + `covjk'

			di in gr _col(2) "_cut`i' " _col(10) "|" in ye _col(13) /*
				*/ %9.8g log(`est') _col(24) %9.8g sqrt(`v2'/`est')
			scalar `e1' = `est'
			scalar `v1' = `v2'
			local i = `i' + 1 
			}
		scalar drop `e1' `e2' `v1' `v2' `covjk' `est'
	}

	else {
	   while `i' < `cat' {
		di in gr _col(2) "_cut`i' " _col(10) "|" in ye _col(13) %9.8g `b'[1,`i'] /*
			*/ _col(24) %9.8g sqrt(`var'[`i',`i'])
		local i = `i' + 1 
		}
	   }
	di in gr _dup(78) "-"

	* Reset internal results and global macros
	matrix post `b' `var', depname(`depv')
	global S_E_depv "`depv'"
	global S_E_l0 = `l0'
	global S_E_ll = `ll'
	global S_E_mdf=`mdf'
	global S_E_chi2 = chiprob(`mdf',-2*(`l0'-`ll'))
	global S_E_pr2 = 1-(`ll'/`l0')
	global S_E_rhs "`bnames'"
	global S_E_nobs=`nobs'
	global S_E_link "`link'"

end


program define _Ditest
	local options "LINK(string) DF(real 1) LRATIO(real 0)"
	parse "`*'"
	if "`link'"=="logit" { local coeff "proportionality of odds" }
	else                 { local coeff "equality of coefficients" }
	di _n in gr "Likelihood-ratio test of `coeff'" _col(56) "chi2(" in ye %1.0f `df' /*
		*/ in gr ")" _col(70) "= " in ye %7.2f `lratio'
	di in gr "across response categories" _col(56) "Prob > chi2   = " /*
		*/ in ye %7.4f chiprob(`df',`lratio')
end


program define _Checks
	local options "Eform CUMulative LINK(string)"
	parse "`*'"
	_Chklink `link'
	local link "$S_3"
	if "`eform'"=="eform" & "`link'"=="probit" {
	    di in red "Exponentiated coefficients not available for probit link model"
	    exit 198
	    }
	if "`cumulative'"~="" {
	    capture assert "`link'"~="logit" & "`link'"~="probit"
	    if _rc~=0 {
		di in red "Use o`link' to fit cumulative probability model with `link' link"
		exit 198
	    	}
	    }
end


program define _Chklink
	local link "`*'"
	parse "`link'", parse(" ")
	if "`2'"~="" {
		di in red "link() invalid: use 1 word only"
		exit 198
	}
	local l = length("`link'")
	if "`link'"==substr("logit",1,`l') 		{ global S_3 "logit" }
	else if "`link'"==substr("probit",1,`l') 	{ global S_3 "probit" }
	else if "`link'"==substr("cloglog",1,`l') 	{ global S_3 "cloglog" }
	else {
		di in red "unknown link() `link'"
		exit 198
	}
end

