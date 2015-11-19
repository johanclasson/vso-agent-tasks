# Tasks for VSO-agents

Invoking PowerShell scripts is often an appealing option for customization of your build- or release flow. This is especially true when you are making changes that are unique for your solution. Just write your script and invoke it!

But directly invoking PowerShell scripts has its limitations:

* If you have to deal with multiple arguments it is easy to get one of them wrong.
* If you find that you have to update a PowerShell script so that it needs to be invoked in a different way, it is a real pain to manually update the command at all places.
* Each build have to include the PowerShell script-files in its source code.

Fortunately, in Visual Studio Online and Team Foundation Server 2015, it is relatively straightforward to package your scripts in a task of your own. Once such a task is installed, it can be shared throughout the collection.

## Installation

The [TFS Cross Platform Command Line utility (tfx-cli)](https://github.com/Microsoft/tfs-cli) is used to install tasks. It is built on Node.js, so if you have not already got Node.js you have to install it. For example with Chocolatey, this can be done with the command `cinst nodejs`.

To install a task run the following commands in a Node.js command prompt:

* `npm install –g tfx-cli` - *This installs the tfx-cli tool.*
* `tfx login` - *The login is reused throughout the entire session.*
  * Enter collection url > `https://yourname.visualstudio.com/DefaultCollection`
  * Enter personal access token > `2lqewmdba7theldpuoqn7zgs46bmz5c2ppkazlwvk2z2segsgqrq` - *This is obviously a bogus token... You can add tokens to access your account at https://yourname.visualstudio.com/_details/security/tokens.* 
* `tfx build tasks upload c:\path-to-repo\vso-agent-tasks\ApplySemanticVersioningToAssemblies`
  * *If you change your mind and do not want a task anymore you can do that with* `tfx build tasks delete b8df3d76-4ee4-45a9-a659-6ead63b536b4`*, where the Guid is easiest found in the task.json of your task.*

## Tasks

* [Apply Semantic Versioning to Assemblies](#apply-semantic-versioning-to-assemblies)

### Apply Semantic Versioning to Assemblies

By use of a regular expression, exactly four version numbers (for example 1.2.3.4) are extracted from the build number. All AssemblyInfo.cs files are then iterated and versions are set in the following attributes:

* `AssemblyVersion` - *Is set to either 1, 1.2, 1.2.3 or 1.2.3.4 depending on what you enter under "Version Numbers in AssemblyVersion-attribute". 1.2 is the default.*
* `AssemblyFileVersion` - *Is set to 1.2.3.4. This is not configurable.* 
* `AssemblyInformationalVersion` - *Is set to either 1.2.3, 1.2.3-abc or 1.2.3-abc0004 depending on what you enter under "Make Release Version", "Prerelease Name" and "Include Build Revision Number".* 

When one of these attributes are present in the AssemblyInfo.cs-file, their entered version-string is replaced. Attributes which are not present are instead added at the end of the file. 

![Apply Semantic Versioning to Assemblies User Interface](/Docs/ApplySemanticVersioningToAssemblies.png?raw=true)

#### Practical Use

The informational version format 1.2.3-abc0004 is [compatible with NuGet](https://docs.nuget.org/create/versioning) and can be used to make prerelease packages from your nightly builds. For example 2.1.3-build0421 could be the [semantic versioning](http://semver.org/) for 421st build targeting the fourth bugfix of the second API update of the 2.0 release.

In fact, NuGet picks up the informational version number when packing a project. Just set the version tag to `<version>$version$</version>` in the nuspec-file and you are good to go. 

When you are planning to make a new release, you might find that it is a good idea to have its intended version numbers fixed and update the build revision number until you are done. If this is the case, use `$(BuildDefinitionName).2.1.3$(Rev:.r)` as the *Build number format* which can be found under the *General* tab. When you think that you are done, you can simply tick "Make Release Version" and build to make a release version which in this case would be 2.1.3. If you would like to build a release candidate, untick "Include Build Revision Number" and replace the "Prerelease Name" to for example RC1 which would result in 2.1.3-RC1. 

#### Version Attributes in .Net

The `AssemblyVersion` is the number that is used by a dll to point out a reference to a specific version of another dll. If this version is changed in a newer dll, those references needs to be updated to target that dll instead. If you follow semantic versioning, the first two version numbers are the one to increase when the public API changes. Therefore it is a good idea to just include those in the assembly version.

The `AssemblyFileVersion` is not used by .Net directly, but is instead useful for historical reference. If you would ever try to figure out from what build a dll has come from, then the assembly file version would help you answer that.

The `AssemblyInformationalVersion` is something human-readable that describes a version, for example 1.0-RC1. This can theoretically be whatever text you prefer, but in this task it is only configurable to the format 1.2.3-abc0004.

#### Advanced Options

You can change the *Build Number Pattern* that is used to extract the version numbers from the build number. If you do, then make sure that you enter matching *Split Characters* and that there would still be exactly four versions present.