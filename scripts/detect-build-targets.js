
function detectBuildTargets(conf) {
    let targets = conf.group.default.targets.flatMap(t => {
        if (conf.group[t])
            return conf.group[t].targets
        else 
            return t
    })
    

    return targets
}

let jsonStr = ""

process.stdin
    .on('data', data => jsonStr += data)
    .on('end', () => {
        let conf = JSON.parse(jsonStr)

        let targets = detectBuildTargets(conf)

        console.log(JSON.stringify(targets))
    })