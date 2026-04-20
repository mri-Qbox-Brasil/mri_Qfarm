local DB = {}

local function sanitizeSQL(content)
    content = content:gsub("/%*.-%*/", "")
    content = content:gsub("%-%-.-\n", "\n")
    return content
end

local function splitStr(inputstr, sep)
    sep = sep or "%s"
    local t = {}
    for str in string.gmatch(inputstr, "[^" .. sep .. "]+") do
        str = str:match("^%s*(.-)%s*$")
        if str and str ~= "" then
            table.insert(t, str)
        end
    end
    return t
end

local function executeQueries(queries, callback)
    local index = 1

    local function executeNextQuery()
        if index > #queries then
            if callback then callback() end
            return
        end

        local query = queries[index]

        MySQL.Async.execute(query, {}, function(rowsChanged)
            print(("Query %d executada com sucesso (%d linhas afetadas)."):format(index, rowsChanged or 0))
            index = index + 1
            executeNextQuery()
        end, function(err)
            print(("Erro ao executar a query %d: %s\nQuery: %s"):format(index, err or "erro desconhecido", query))
        end)
    end

    executeNextQuery()
end

function DB.createTables()
    local filePath = "database.sql"
    local content = LoadResourceFile(GetCurrentResourceName(), filePath)

    if not content then
        print("Erro: arquivo " .. filePath .. " não encontrado.")
        return
    end

    content = sanitizeSQL(content)
    local queries = splitStr(content, ";")
    executeQueries(queries, function()
        print("Todas as tabelas foram verificadas/criadas.")
    end)
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("Recurso " .. resourceName .. " iniciado. Verificando/criando tabelas...")
        DB.createTables()
    end
end)

return DB
