{
    // console.clear()
    let stack = [""]
    const labels = {}
    const addLabel = (name, value) => {
        if (name === null) {
            return value
        }
        labels[name[1]] = value
        return value
    }
}

Config
    = EOF { return {} }
    / value:Object {
        return value
    }
Object
    = _N label:(samedent Label)? items:(samedent (ObjectItem / ArrayItem))+ {
        const parts = items.reduce(
            (list, item) => {
                const base = item[1]
                if (Array.isArray(base[0]) === true) {
                    list.push(...base)
                    return list
                }
                list.push(base)
                return list
            },
            []
        )
        if (parts[0][0] === null) {
            const bad = parts.find(p => p[0] !== null)
            if (bad !== undefined) {
                error("Object entry found when expecting Array item", bad[2])
            }
            return addLabel(label, parts.map(p => p[1]))
        }
        const bad = parts.find(p => p[0] === null)
        if (bad !== undefined) {
            error("Array item found when expecting Object entry", bad[2])
        }
        return addLabel(label, Object.fromEntries(parts))
    }
ObjectKey
    = key:$([^\r\n:\-&] [^\r\n:]*) ":" { return key }
ObjectItem
    = key:ObjectKey __ value:Value {
        return [ key, value, location() ]
    }
    / key:ObjectKey __ value:MLString {
        return [ key, value, location() ]
    }
    / key:ObjectKey __N &indent value:Object &dedent {
        return [ key, value, location() ]
    }
    / key:"&:" __ ref:Ref EOL {
        return Object.entries(ref)
    }

Array
    = items:(samedent ArrayItem)* {
        return items.map(i => i[1])
    }
ArrayItem
    = "- " first:ObjectItem rest:(&indent samedent ObjectItem+ &dedent) {
        const obj = Object.fromEntries([
            first,
                ...rest[2]
        ])
        return [ null, obj, location() ]
    }
    / "- " first:ObjectItem {
        const obj = Object.fromEntries([
            first,
        ])
        return [ null, obj, location() ]
    }
    / "- " value:Value { return [ null, value, location() ] }
    / "&-" ref:Ref EOL {
        return labels[ref].map(
            value => [null, value]
        )
    }

indent
    = i:_ &{
        if (i.length > stack[0].length) {
            stack.unshift(i)
            return true
        }
        return false
    }
dedent
    = i:_ &{
        const idx = stack.indexOf(i)
        if (idx !== -1) {
            stack.shift()
            return true
        }
        error("mismatched indentation")
        return false
    }
samedent
    = i:_ &{
        return i === stack[0]
    }

letter = [a-z]

Value
    = value:Number EOL { return value }
    / value:Bool EOL { return value }
    / value:Null EOL { return value }
    / value:Ref EOL { return value }
    / value:String EOL { return value }

Bool
    = "true" { return true }
    / "false" { return false }

Null = "null" { return null }
String
    = '"' value:$(([^"] / '\\"')*) '"' { return value }
    / "'" value:$(([^'] / "\\'")*) "'" { return value }
    / value:$([^ \r\n\t"'|>] [^\r\n\t]*) { return value }
MLString
    = ">" _N &indent lines:StringLine+ &dedent { return lines.join("\n") }
StringLine
    = samedent line:$([^\r\n]+) EOL { return line }

Number
    = "0x" text:$([0-9a-fA-F]+) { return parseInt(text, 16) }
    / "0b" text:$([01]+) { return parseInt(text, 2) }
    / text:$([0-9]+ "." [0-9]+) { return parseFloat(text) }
    / text:$([0-9]+) { return parseInt(text, 10) }

Label
    = "&" label:$([^\r\n:] [^\r\n:]*) EOL { return label }
Ref
    = "*" label:$([^\r\n:] [^\r\n:]*) {
        if (labels[label] === undefined) {
            error(`Label "${label}" is not constructed yet`)
        }
        return labels[label]
    }

_ "indent"
    = $(" "*)
__ "whitespace"
    = " "+
__N "newline" = [\r\n]+
_N "newline" = [\r\n]*
EOF = !.
EOL = __N / EOF
