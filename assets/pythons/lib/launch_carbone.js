'use strict';

// returns the value of `num1`
//console.log("ARgumentos")
//console.log(process.argv);

var myArgs = process.argv.slice(2);
//console.log('myArgs: ', myArgs);
var pathRoot = myArgs[0]
//console.log('pathRoot: ', pathRoot);
var docId = myArgs[1]
//console.log('docId: ', docId);
var docName = myArgs[2]
//console.log('docName: ', docName);
var useDocId = myArgs[3]

const fs = require('fs');
const carbone = require('carbone');

let rawdata = fs.readFileSync(pathRoot+'/doc/issues.json');  
let data = JSON.parse(rawdata);

var options = {
variableStr  : '{#doc = '+docId+'}',
};

if (useDocId == "0") {
	carbone.render(pathRoot+'/templates/issues_template.odt', data, options, function(err, result){
	if (err) return console.log(err);
	fs.writeFileSync(pathRoot+'/doc/pr'+docName+'.odt', result);
	});

	carbone.render(pathRoot+'/templates/issues_template.ods', data, options, function(err, result){
	if (err) return console.log(err);
	fs.writeFileSync(pathRoot+'/doc/pr'+docName+'.ods', result);
	});
} else {
	carbone.render(pathRoot+'/templates/issues_byperson_template.odt', data, options, function(err, result){
	if (err) return console.log(err);
	fs.writeFileSync(pathRoot+'/doc/'+docName+'.odt', result);
	});

	carbone.render(pathRoot+'/templates/issues_byperson_template.ods', data, options, function(err, result){
	if (err) return console.log(err);
	fs.writeFileSync(pathRoot+'/doc/'+docName+'.ods', result);
	});
}