// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "KenBurns",
	platforms: [
		.iOS(.v12)
	],
	products: [
		.library(
			name: "KenBurns",
			targets: ["KenBurns"]),
	],
	dependencies: [
		.package(url: "git@github.com:onevcat/Kingfisher.git",
			.upToNextMajor(from: "7.4.0"))],
	targets: [.target(name: "KenBurns",
					  dependencies: ["Kingfisher", "CalmParametricAnimations"],
					  path: "KenBurns/Classes"),
		.target(name: "CalmParametricAnimations", path: "CalmParametricAnimations")]

)
