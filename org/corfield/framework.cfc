<cfcomponent><cfscript>
/*
	Copyright (c) 2009, Sean Corfield

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/

	/*
	 * call this from your setupApplication() method to tell the framework
	 * about your bean factory - only assumption is that it supports:
	 * - containsBean(name) - returns true if factory contains that named bean, else false
	 * - getBean(name) - returns the named bean
	 */
	function setBeanFactory(factory) {
	
		application[variables.framework.applicationKey].factory = factory;
	
	}

	/*
	 * override this to provide application-specific initialization
	 * if you want the framework to use a bean factory and autowire
	 * controllers and services, call setBeanFactory(factory) in your
	 * setupApplication() method
	 * you do not need to call super.setupApplication()
	 */
	function setupApplication() { }

	/*
	 * override this to provide session-specific initialization
	 * you do not need to call super.setupSession()
	 */
	function setupSession() { }

	/*
	 * override this to provide request-specific initialization
	 * you do not need to call super.setupRequest()
	 */
	function setupRequest() { }

	/*
	 * it is better to set up your application configuration in
	 * your setupApplication() method since that is called on a
	 * framework reload
	 * if you do override onApplicationStart(), you must call
	 * super.onApplicationStart() first
	 */
	function onApplicationStart() {
		setupFrameworkDefaults();
		setupApplicationWrapper();
	}
	
	/*
	 * it is better to set up your session configuration in
	 * your setupSession() method
	 * if you do override onSessionStart(), you must call
	 * super.onSessionStart() first
	 */
	function onSessionStart() {
		setupFrameworkDefaults();
		setupSession();
	}
	
	/*
	 * it is better to set up your request configuration in
	 * your setupRequest() method
	 * if you do override onRequestStart(), you must call
	 * super.onRequestStart() first
	 */
	function onRequestStart(targetPath) {
		
		setupFrameworkDefaults();
		
		if ( structKeyExists(URL, variables.framework.reload) and 
				URL[variables.framework.reload] is variables.framework.password ) {
			setupApplicationWrapper();
		}
		
		if ( structKeyExists(variables.framework, 'base') ) {
			request.base = variables.framework.base;
			if ( right(request.base,1) is not '/' ) {
				request.base &= '/';
			}
		} else {
			request.base = getDirectoryFromPath(targetPath);
		}
		request.base = replace( request.base, chr(92), '/', 'all' );
		if ( structKeyExists(variables.framework, 'cfcbase') ) {
			request.cfcbase = variables.framework.cfcbase;
		} else {
			if ( len(request.base) eq 1 ) {
				request.cfcbase = '';
			} else {
				request.cfcbase = replace( mid(request.base, 2, len(request.base)-2 ), '/', '.', 'all' );
			}
		}

		if ( !structKeyExists(request, 'context') ) {
			request.context = { };
		}
		structAppend(request.context,URL);
		structAppend(request.context,form);

		if ( !structKeyExists(request.context, variables.framework.action) ) {
			request.context[variables.framework.action] = variables.framework.home;
		}
		if ( listLen(request.context[variables.framework.action], '.') eq 1 ) {
			request.context[variables.framework.action] &= '.default';
		}
		request.action = request.context[variables.framework.action];

		setupRequestWrapper();
		
		// allow CFC requests through directly:
		if ( right(targetPath,4) is '.cfc' ) {
			structDelete(this, 'onRequest');
			structDelete(variables, 'onRequest');
		}
	}
	
	/*
	 * not intended to be overridden, automatically deleted for CFC requests
	 */
	function onRequest(targetPath) {
		
		var out = 0;
		var i = 0;
		
		if ( structKeyExists( request, 'controller' ) ) {
			doController( request.controller, 'before' );
			doController( request.controller, 'start' & request.item );
			doController( request.controller, request.item );
		}
		if ( structKeyExists( request, 'service' ) ) {
			doService( request.service, request.item );
		}
		if ( structKeyExists( request, 'controller' ) ) {
			doController( request.controller, 'end' & request.item );
			doController( request.controller, 'after' );
		}
		out = view( request.view );
		for (i = 1; i lte arrayLen(request.layouts); ++i) {
			out = layout( request.layouts[i], out );
			if ( structKeyExists(request, 'layout') and !request.layout ) {
				break;
			}
		}
		writeOutput( out );
	}
	
	/*
	 * can be overridden, calling super.onError(exception,event) is optional
	 * depending on what error handling behavior you want
	 */
	function onError(exception,event) {

		try {
			request.action = variables.framework.error;
			request.exception = exception;
			request.event = event;
			setupRequestWrapper();
			onRequest('');
		} catch (any e) {
			fail(exception,event);
		}

	}
	
	/*
	 * returns whatever the framework has been told is a bean factory
	 */
	function getBeanFactory() {
		
		return application[variables.framework.applicationKey].factory;
	}
	
	/*
	 * returns true iff the framework has been told about a bean factory
	 */
	function hasBeanFactory() {
		
		return structKeyExists(application[variables.framework.applicationKey], 'factory');
	}
	
	/*
	 * do not call/override - set your framework configuration
	 * using variables.framework = { key/value pairs} in the pseudo-constructor
	 * of your Application.cfc
	 */
	function setupFrameworkDefaults() { // "private"

		// default values for Application::variables.framework structure:
		if ( !structKeyExists(variables, 'framework') ) {
			variables.framework = { };
		}
		if ( !structKeyExists(variables.framework, 'action') ) {
			variables.framework.action = 'action';
		}
		if ( !structKeyExists(variables.framework, 'home') ) {
			variables.framework.home = 'main.default';
		}
		if ( !structKeyExists(variables.framework, 'error') ) {
			variables.framework.error = 'main.error';
		}
		if ( !structKeyExists(variables.framework, 'reload') ) {
			variables.framework.reload = 'reload';
		}
		if ( !structKeyExists(variables.framework, 'password') ) {
			variables.framework.password = 'true';
		}
		if ( !structKeyExists(variables.framework, 'applicationKey') ) {
			variables.framework.applicationKey = 'org.corfield.framework';
		}

	}

	/*
	 * do not call/override
	 */
	function setupApplicationWrapper() { // "private"

		var framework = {
				cache = {
					lastReload = now(),
					controllers = { },
					services = { }
				}
			};
		application[variables.framework.applicationKey] = framework;
		setupApplication();

	}
	
	/*
	 * do not call/override
	 */
	function setupSessionWrapper() { // "private"
		setupSession();
	}

	/*
	 * do not call/override
	 */
	function setupRequestWrapper() { // "private"
	
		// TODO: consider listLen(request.action,'.') gt 2
		request.section = listFirst(request.action, '.');
		request.item = listLast(request.action, '.');

		request.controller = getController(request.section);
		
		request.service = getService(request.section);
		
		if ( fileExists( expandPath( request.base & 'views/' & request.section & '/' & request.item & '.cfm' ) ) ) {
			request.view = request.section & '/' & request.item;
		}
		
		request.layouts = [ ];
		if ( fileExists( expandPath( request.base & 'layouts/' & request.section & '/' & request.item & '.cfm' ) ) ) {
			arrayAppend(request.layouts, request.section & '/' & request.item);
		}
		if ( request.item is not 'default' and
				fileExists( expandPath( request.base & 'layouts/' & request.section & '/default.cfm' ) ) ) {
			arrayAppend(request.layouts, request.section & '/default');
		}
		if ( fileExists( expandPath( request.base & 'layouts/' & request.section & '.cfm' ) ) ) {
			arrayAppend(request.layouts, request.section);
		}
		if ( request.section is not 'default' and
				fileExists( expandPath( request.base & 'layouts/default.cfm' ) ) ) {
			arrayAppend(request.layouts, 'default');
		}
		
		setupRequest();

	}
	
	/*
	 * do not call/override
	 */
	function getController(section) { // "private"
		var controller = getCachedComponent("controller",section);
		if ( isDefined('controller') ) {
			return controller;
		}
	}
	
	/*
	 * do not call/override
	 */
	function getService(section) { // "private"
		var service = getCachedComponent("service",section);
		if ( isDefined('service') ) {
			return service;
		}
	}
	
	/*
	 * do not call/override
	 */
	function getCachedComponent(type,section) { // "private" -- not completely thread safe yet
		
		var cache = application[variables.framework.applicationKey].cache;
		var types = type & 's';
		var cfc = 0;
		
		if ( structKeyExists(cache[types], section) ) {
			return cache[types][section];
		}
		
		if ( hasBeanFactory() and getBeanFactory().containsBean( section & type ) ) {
			cfc = getBeanFactory().getBean( section & type );
			cache[types][section] = cfc;
			return cfc;
		}
		
		if ( fileExists( expandPath( request.base & types & '/' & section & '.cfc' ) ) ) {
			cfc = createObject( 'component', request.cfcbase & '.' & types & '.' & section );
			if ( structKeyExists( cfc, 'init' ) ) {
				cfc.init( this );
			}
			if ( hasBeanFactory() ) {
				autowire( cfc );
			}
			cache[types][section] = cfc;
			return cfc;
		}

	}
	
</cfscript><cfsilent>
	
	<cffunction name="view" output="false" hint="Returns the UI generated by the named view. Can be called from layouts.">
		<cfargument name="path" />
		
		<cfset var rc = request.context />
		<cfset var response = '' />
		
		<cfsavecontent variable='response'><cfinclude template="#request.base#views/#arguments.path#.cfm"/></cfsavecontent>
		
		<cfreturn response />

	</cffunction>
	
	<cffunction name="layout" output="false" hint="Returns the UI generated by the named layout.">
		<cfargument name="path" />
		<cfargument name="body" />
		
		<cfset var rc = request.context />
		<cfset var response = '' />
		
		<cfsavecontent variable='response'><cfinclude template="#request.base#layouts/#arguments.path#.cfm"/></cfsavecontent>
		
		<cfreturn response />
	</cffunction>
	
	<cffunction name="autowire" access="private" output="false" 
			hint="Used to autowire controllers and services from a bean factory.">
		<cfargument name="cfc" />
		
		<cfset var key = 0 />
		<cfset var property = 0 />
		<cfset var args = 0 />
		
		<cfloop item="key" collection="#arguments.cfc#">
			<cfif len(key) gt 3 and left(key,3) is "set">
				<cfset property = right(key, len(key)-3) />
				<cfif getBeanFactory().containsBean(property)>
					<cfset args = [ getBeanFactory().getBean(property) ] />
					<cfinvoke component="#arguments.cfc#" method="#key#" argumentCollection="#args#" />
				</cfif>
			</cfif>
		</cfloop>
		
	</cffunction>
	
	<cffunction name="doController" access="private" output="false" hint="Executes a controller in context.">
		<cfargument name="cfc" />
		<cfargument name="method" />
		
		<cfif structKeyExists(arguments.cfc,arguments.method)>
			<cfinvoke component="#arguments.cfc#" method="#arguments.method#" rc="#request.context#" />
		</cfif>

	</cffunction>
	
	<cffunction name="doService" access="private" output="false" hint="Executes a controller in context.">
		<cfargument name="cfc" />
		<cfargument name="method" />
		
		<cfif structKeyExists(arguments.cfc,arguments.method)>
			<cfinvoke component="#arguments.cfc#" method="#arguments.method#"
				argumentCollection="#request.context#" returnVariable="request.context.data" />
		</cfif>

	</cffunction>
	
</cfsilent><cffunction name="fail" access="private" hint="Bare bones 'last resort' default error handler."
		><cfargument name="exception"
		/><cfargument name="event"
		
		/><h1>Exception<h1>
<h2>Occurred during <cfoutput>#arguments.event#</cfoutput></h2>
<cfdump var="#arguments.exception#" label="Exception"/>
</cffunction></cfcomponent>